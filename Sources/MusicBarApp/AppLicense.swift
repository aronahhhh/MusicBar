import Foundation

final class AppLicense: ObservableObject {
    @Published private(set) var trialStartDate: Date
    @Published private(set) var isPurchased: Bool

    private let trialStartDateKey = "license.trialStartDate"
    private let purchasedKey = "license.isPurchased"

    init() {
        if let savedDate = UserDefaults.standard.object(forKey: trialStartDateKey) as? Date {
            trialStartDate = savedDate
        } else {
            let now = Date()
            trialStartDate = now
            UserDefaults.standard.set(now, forKey: trialStartDateKey)
        }

        isPurchased = UserDefaults.standard.bool(forKey: purchasedKey)
    }

    var trialEndsAt: Date {
        Calendar.current.date(byAdding: .day, value: AppEdition.trialDurationDays, to: trialStartDate) ?? trialStartDate
    }

    var isTrialActive: Bool {
        Date() < trialEndsAt
    }

    var isEntitled: Bool {
        isPurchased || isTrialActive
    }

    var daysRemaining: Int {
        guard isTrialActive else {
            return 0
        }

        let seconds = trialEndsAt.timeIntervalSince(Date())
        return max(1, Int(ceil(seconds / 86_400)))
    }

    var statusText: String {
        if isPurchased {
            return "Full version unlocked"
        }

        if isTrialActive {
            return "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in trial"
        }

        return "Trial expired"
    }

    var detectedRegionName: String {
        if isMainlandChina {
            return "中国大陆 🇨🇳"
        }

        return Locale.current.localizedString(forRegionCode: detectedRegionCode) ?? detectedRegionCode
    }

    var detectedRegionCode: String {
        Locale.current.language.region?.identifier ?? "US"
    }

    var isMainlandChina: Bool {
        detectedRegionCode.uppercased() == "CN"
    }

    var localizedPrice: String {
        isMainlandChina ? "RMB 3.99" : "$1.99"
    }

    var regionPricingText: String {
        "MusicBar detected your country or region as \(detectedRegionName). The full version price is \(localizedPrice)."
    }

    var purchaseURL: URL {
        URL(string: AppEdition.purchaseURLString) ?? URL(string: AppEdition.githubURLString)!
    }
}
