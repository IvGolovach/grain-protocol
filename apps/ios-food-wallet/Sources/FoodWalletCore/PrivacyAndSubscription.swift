import Foundation

public enum PrivacyConsentState: String, Codable, Equatable, Sendable {
    case notRequested
    case granted
    case denied

    public var label: String {
        switch self {
        case .notRequested:
            return "AI photo analysis not enabled"
        case .granted:
            return "AI photo analysis allowed"
        case .denied:
            return "AI photo analysis disabled"
        }
    }
}

public enum SubscriptionTier: String, Codable, Equatable, Sendable {
    case free
    case pro

    public var label: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

public struct SubscriptionState: Codable, Equatable, Sendable {
    public var tier: SubscriptionTier
    public var monthlyPhotoEstimateLimit: Int
    public var usedPhotoEstimates: Int

    public init(tier: SubscriptionTier, monthlyPhotoEstimateLimit: Int, usedPhotoEstimates: Int = 0) {
        self.tier = tier
        self.monthlyPhotoEstimateLimit = monthlyPhotoEstimateLimit
        self.usedPhotoEstimates = usedPhotoEstimates
    }

    public static let free = SubscriptionState(tier: .free, monthlyPhotoEstimateLimit: 10)
    public static let pro = SubscriptionState(tier: .pro, monthlyPhotoEstimateLimit: 500)

    public var remainingPhotoEstimates: Int {
        max(0, monthlyPhotoEstimateLimit - usedPhotoEstimates)
    }

    public var summary: String {
        "\(tier.label): \(remainingPhotoEstimates) photo estimates left"
    }
}

public struct PrivacyPromise: Equatable, Sendable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    public static let defaultPromises: [PrivacyPromise] = [
        PrivacyPromise(
            title: "Photos create drafts only",
            detail: "The app stores confirmed nutrition data, not raw meal photos."
        ),
        PrivacyPromise(
            title: "You confirm every entry",
            detail: "AI estimates never become Food Wallet records until you save them."
        ),
        PrivacyPromise(
            title: "Safe summaries stay safe",
            detail: "Exports omit raw photos, protocol payloads, snapshots, and private trust material."
        ),
    ]
}
