import Combine
import Foundation

enum LyricsState: Equatable {
    case idle
    case loading
    case loaded(title: String, artist: String, lines: [LyricLine], isSynced: Bool)
    case unavailable(message: String)
}

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: TimeInterval?
    let text: String
}

final class LyricsService: ObservableObject {
    @Published private(set) var state: LyricsState = .idle

    private var activeTask: URLSessionDataTask?
    private var activeTasks: [URLSessionDataTask] = []
    private var cachedLyrics: [String: LyricsState] = [:]
    private var activeLoadingKey: String?

    func loadLyrics(for track: TrackInfo) {
        let key = cacheKey(for: track)
        if let cached = cachedLyrics[key] {
            state = cached
            return
        }

        if activeLoadingKey == key {
            return
        }

        cancelActiveTasks()
        activeLoadingKey = key
        state = .loading

        fetchFromLRCLIBExact(track: track) { [weak self] exactState in
            guard let self else {
                return
            }

            if case .loaded = exactState {
                self.finishLoading(exactState, key: key)
                return
            }

            self.fetchFromLRCLIBSearch(track: track) { [weak self] searchState in
                guard let self else {
                    return
                }

                if case .loaded = searchState {
                    self.finishLoading(searchState, key: key)
                    return
                }

                self.fetchFromNetEase(track: track) { [weak self] fallbackState in
                    self?.finishLoading(fallbackState, key: key)
                }
            }
        }
    }

    func reset() {
        cancelActiveTasks()
        state = .idle
    }

    private func fetchFromLRCLIBExact(track: TrackInfo, completion: @escaping (LyricsState) -> Void) {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else {
            completion(.unavailable(message: "Lyrics service unavailable."))
            return
        }

        components.queryItems = [
            URLQueryItem(name: "track_name", value: normalizedTitle(track.title)),
            URLQueryItem(name: "artist_name", value: primaryArtist(track.artist)),
            URLQueryItem(name: "album_name", value: normalizedTitle(track.album)),
            URLQueryItem(name: "duration", value: durationString(track.duration))
        ]
        components.queryItems = components.queryItems?.filter { !($0.value ?? "").isEmpty }

        guard let url = components.url else {
            completion(.unavailable(message: "Could not search lyrics."))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("MusicBar/0.1.0", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            completion(self.parseLyricsResponse(
                data: data,
                response: response,
                title: track.displayTitle,
                artist: track.displayArtist
            ))
        }

        activeTask = task
        activeTasks.append(task)
        task.resume()
    }

    private func fetchFromLRCLIBSearch(track: TrackInfo, completion: @escaping (LyricsState) -> Void) {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
            completion(.unavailable(message: "Lyrics service unavailable."))
            return
        }

        let title = normalizedTitle(track.title)
        let artist = primaryArtist(track.artist)
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components.url else {
            completion(.unavailable(message: "Could not search lyrics."))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("MusicBar/0.1.0", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data,
                  let payloads = try? JSONDecoder().decode([LyricsResponse].self, from: data),
                  let best = self.bestLRCLIBMatch(from: payloads, track: track) else {
                completion(.unavailable(message: "No lyrics found for this track."))
                return
            }

            completion(self.lyricsState(from: best, title: track.displayTitle, artist: track.displayArtist))
        }

        activeTask = task
        activeTasks.append(task)
        task.resume()
    }

    private func fetchFromNetEase(track: TrackInfo, completion: @escaping (LyricsState) -> Void) {
        guard let url = URL(string: "https://music.163.com/api/search/get/web?csrf_token=") else {
            completion(.unavailable(message: "No lyrics found for this track."))
            return
        }

        let query = "\(normalizedTitle(track.title)) \(primaryArtist(track.artist))"
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.httpMethod = "POST"
        request.setValue("MusicBar/0.1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "s": query,
            "type": "1",
            "limit": "8",
            "offset": "0"
        ]).data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data,
                  let searchPayload = try? JSONDecoder().decode(NetEaseSearchResponse.self, from: data),
                  let song = self.bestNetEaseMatch(from: searchPayload.result?.songs ?? [], track: track) else {
                completion(.unavailable(message: "No lyrics found for this track."))
                return
            }

            self.fetchNetEaseLyrics(songID: song.id, track: track, completion: completion)
        }

        activeTask = task
        activeTasks.append(task)
        task.resume()
    }

    private func fetchNetEaseLyrics(songID: Int, track: TrackInfo, completion: @escaping (LyricsState) -> Void) {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(songID)&lv=-1&kv=-1&tv=-1") else {
            completion(.unavailable(message: "No lyrics found for this track."))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("MusicBar/0.1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data,
                  let payload = try? JSONDecoder().decode(NetEaseLyricsResponse.self, from: data),
                  let lrc = payload.lrc?.lyric,
                  !lrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(.unavailable(message: "No lyrics found for this track."))
                return
            }

            let lines = self.syncedLyricLines(from: lrc)
            if lines.isEmpty {
                completion(.loaded(
                    title: track.displayTitle,
                    artist: track.displayArtist,
                    lines: self.plainLyricLines(from: lrc),
                    isSynced: false
                ))
            } else {
                completion(.loaded(
                    title: track.displayTitle,
                    artist: track.displayArtist,
                    lines: lines,
                    isSynced: true
                ))
            }
        }

        activeTask = task
        activeTasks.append(task)
        task.resume()
    }

    private func parseLyricsResponse(data: Data?, response: URLResponse?, title: String, artist: String) -> LyricsState {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .unavailable(message: "Could not connect to lyrics service.")
        }

        guard httpResponse.statusCode == 200, let data else {
            return .unavailable(message: "No lyrics found for this track.")
        }

        guard let payload = try? JSONDecoder().decode(LyricsResponse.self, from: data) else {
            return .unavailable(message: "Could not read lyrics.")
        }

        return lyricsState(from: payload, title: title, artist: artist)
    }

    private func lyricsState(from payload: LyricsResponse, title: String, artist: String) -> LyricsState {
        if let syncedLyrics = payload.syncedLyrics,
           !syncedLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = syncedLyricLines(from: syncedLyrics)
            guard !lines.isEmpty else {
                return .unavailable(message: "No lyrics found for this track.")
            }

            return .loaded(
                title: title,
                artist: artist,
                lines: lines,
                isSynced: true
            )
        }

        guard let plainLyrics = payload.plainLyrics,
              !plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unavailable(message: "No lyrics found for this track.")
        }

        return .loaded(
            title: title,
            artist: artist,
            lines: plainLyricLines(from: plainLyrics),
            isSynced: false
        )
    }

    private func finishLoading(_ nextState: LyricsState, key: String) {
        DispatchQueue.main.async {
            guard self.activeLoadingKey == key else {
                return
            }

            self.cachedLyrics[key] = nextState
            self.activeLoadingKey = nil
            self.state = nextState
        }
    }

    private func cancelActiveTasks() {
        activeTask?.cancel()
        activeTasks.forEach { $0.cancel() }
        activeTask = nil
        activeLoadingKey = nil
        activeTasks.removeAll()
    }

    private func cacheKey(for track: TrackInfo) -> String {
        "\(track.title.lowercased())|\(track.artist.lowercased())|\(track.album.lowercased())"
    }

    private func plainLyricLines(from lyrics: String) -> [LyricLine] {
        lyrics
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: nil, text: $0.element) }
    }

    private func syncedLyricLines(from lyrics: String) -> [LyricLine] {
        lyrics
            .components(separatedBy: .newlines)
            .compactMap { rawLine -> (TimeInterval, String)? in
                guard let closeBracket = rawLine.firstIndex(of: "]"),
                      rawLine.first == "[",
                      let time = parseTimestamp(String(rawLine[rawLine.index(after: rawLine.startIndex)..<closeBracket])) else {
                    return nil
                }

                let text = rawLine[rawLine.index(after: closeBracket)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else {
                    return nil
                }

                return (time, text)
            }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    private func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let parts = timestamp.components(separatedBy: ":")
        guard parts.count == 2,
              let minutes = TimeInterval(parts[0]),
              let seconds = TimeInterval(parts[1]) else {
            return nil
        }

        return minutes * 60 + seconds
    }

    private func bestLRCLIBMatch(from payloads: [LyricsResponse], track: TrackInfo) -> LyricsResponse? {
        payloads
            .filter { ($0.syncedLyrics ?? $0.plainLyrics) != nil }
            .max { scoreLRCLIB($0, track: track) < scoreLRCLIB($1, track: track) }
    }

    private func scoreLRCLIB(_ payload: LyricsResponse, track: TrackInfo) -> Int {
        var score = 0
        let title = comparable(normalizedTitle(track.title))
        let artist = comparable(primaryArtist(track.artist))
        let payloadTitle = comparable(payload.trackName ?? payload.name ?? "")
        let payloadArtist = comparable(payload.artistName ?? "")

        if payloadTitle == title {
            score += 50
        } else if payloadTitle.contains(title) || title.contains(payloadTitle) {
            score += 25
        }

        if !artist.isEmpty, payloadArtist.contains(artist) || artist.contains(payloadArtist) {
            score += 20
        }

        if let trackDuration = track.duration,
           let payloadDuration = payload.duration,
           abs(trackDuration - payloadDuration) <= 3 {
            score += 15
        }

        if payload.syncedLyrics != nil {
            score += 10
        }

        return score
    }

    private func bestNetEaseMatch(from songs: [NetEaseSong], track: TrackInfo) -> NetEaseSong? {
        songs.max { scoreNetEase($0, track: track) < scoreNetEase($1, track: track) }
    }

    private func scoreNetEase(_ song: NetEaseSong, track: TrackInfo) -> Int {
        var score = 0
        let title = comparable(normalizedTitle(track.title))
        let artist = comparable(primaryArtist(track.artist))
        let songTitle = comparable(normalizedTitle(song.name))
        let songArtists = comparable(song.artists.map(\.name).joined(separator: " "))

        if songTitle == title {
            score += 50
        } else if songTitle.contains(title) || title.contains(songTitle) {
            score += 25
        }

        if !artist.isEmpty, songArtists.contains(artist) || artist.contains(songArtists) {
            score += 20
        }

        if let trackDuration = track.duration,
           let duration = song.duration,
           abs(trackDuration - TimeInterval(duration) / 1000) <= 4 {
            score += 15
        }

        return score
    }

    private func normalizedTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"(?i)\s*[-–—]\s*(live|remaster(ed)?|acoustic|伴奏|纯音乐|电影.*|电视剧.*|theme.*)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[\(（\[].*?[\)）\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func primaryArtist(_ value: String) -> String {
        value
            .components(separatedBy: CharacterSet(charactersIn: "/、,&，;；"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? value
    }

    private func comparable(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[\s　·・\.\-_'"]"#, with: "", options: .regularExpression)
    }

    private func durationString(_ duration: TimeInterval?) -> String {
        guard let duration else {
            return ""
        }

        return String(Int(duration.rounded()))
    }

    private func formEncoded(_ values: [String: String]) -> String {
        values
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct LyricsResponse: Decodable {
    let name: String?
    let trackName: String?
    let artistName: String?
    let duration: TimeInterval?
    let plainLyrics: String?
    let syncedLyrics: String?
}

private struct NetEaseSearchResponse: Decodable {
    let result: NetEaseSearchResult?
}

private struct NetEaseSearchResult: Decodable {
    let songs: [NetEaseSong]?
}

private struct NetEaseSong: Decodable {
    let id: Int
    let name: String
    let artists: [NetEaseArtist]
    let duration: Int?
}

private struct NetEaseArtist: Decodable {
    let name: String
}

private struct NetEaseLyricsResponse: Decodable {
    let lrc: NetEaseLyricsContent?
}

private struct NetEaseLyricsContent: Decodable {
    let lyric: String?
}
