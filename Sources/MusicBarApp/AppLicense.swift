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

    var purchaseURL: URL {
        URL(string: AppEdition.purchaseURLString) ?? URL(string: AppEdition.githubURLString)!
    }
}
