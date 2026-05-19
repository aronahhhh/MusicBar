import CoreAudio
import Foundation

struct SystemAudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let name: String
    let transport: String
    let isDefault: Bool

    var displayName: String {
        transport.isEmpty ? name : "\(name)"
    }
}

final class SystemAudioService {
    func outputDevices() -> [SystemAudioDevice] {
        let defaultDevice = defaultOutputDeviceID()
        return allAudioDevices().compactMap { deviceID in
            guard hasOutputStreams(deviceID), let name = deviceName(deviceID) else {
                return nil
            }

            return SystemAudioDevice(
                id: deviceID,
                name: name,
                transport: transportName(for: deviceID),
                isDefault: deviceID == defaultDevice
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func outputVolume() -> Int {
        guard let deviceID = defaultOutputDeviceID() else {
            return 100
        }

        if let masterVolume = readVolume(deviceID: deviceID, channel: kAudioObjectPropertyElementMain) {
            return Int((masterVolume * 100).rounded())
        }

        let left = readVolume(deviceID: deviceID, channel: 1)
        let right = readVolume(deviceID: deviceID, channel: 2)
        let values = [left, right].compactMap { $0 }
        guard !values.isEmpty else {
            return 100
        }

        let average = values.reduce(0, +) / Float32(values.count)
        return Int((average * 100).rounded())
    }

    func setOutputVolume(_ volume: Int) {
        guard let deviceID = defaultOutputDeviceID() else {
            return
        }

        let scalar = Float32(min(max(volume, 0), 100)) / 100
        if setVolume(deviceID: deviceID, channel: kAudioObjectPropertyElementMain, value: scalar) {
            return
        }

        _ = setVolume(deviceID: deviceID, channel: 1, value: scalar)
        _ = setVolume(deviceID: deviceID, channel: 2, value: scalar)
    }

    func setDefaultOutputDevice(_ deviceID: AudioObjectID) {
        var targetDevice = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &targetDevice
        )
    }

    private func defaultOutputDeviceID() -> AudioObjectID? {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        return status == noErr && deviceID != kAudioObjectUnknown ? deviceID : nil
    }

    private func allAudioDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        )

        return status == noErr ? devices : []
    }

    private func hasOutputStreams(_ deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private func deviceName(_ deviceID: AudioObjectID) -> String? {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        guard status == noErr else {
            return nil
        }

        return name as String
    }

    private func transportName(for deviceID: AudioObjectID) -> String {
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport) == noErr else {
            return ""
        }

        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return "Built-in"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "Bluetooth"
        case kAudioDeviceTransportTypeUSB:
            return "USB"
        case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI:
            return "Display"
        case kAudioDeviceTransportTypeAirPlay:
            return "AirPlay"
        default:
            return ""
        }
    }

    private func readVolume(deviceID: AudioObjectID, channel: AudioObjectPropertyElement) -> Float32? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            return nil
        }

        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr ? volume : nil
    }

    private func setVolume(deviceID: AudioObjectID, channel: AudioObjectPropertyElement, value: Float32) -> Bool {
        var volume = value
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            return false
        }

        return AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &volume
        ) == noErr
    }
}
