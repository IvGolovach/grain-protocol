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

    public static let plus: SubscriptionTier = .pro

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "free":
            self = .free
        case "pro", "plus":
            self = .pro
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown subscription tier \(value)"
            )
        }
    }

    public var label: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "MealMark Plus"
        }
    }

    public var isPlus: Bool {
        self == .pro
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
    public static let plus = SubscriptionState(tier: .plus, monthlyPhotoEstimateLimit: 500)
    public static let pro = SubscriptionState.plus

    public init(entitlement: MealMarkEntitlement, usage: [MealMarkUsageSnapshot] = []) {
        let photoUsage = usage.first { $0.feature == .photoAnalysis }
        self.init(
            tier: entitlement.tier,
            monthlyPhotoEstimateLimit: photoUsage?.limit ?? entitlement.tier.defaultMonthlyLimit(for: .photoAnalysis),
            usedPhotoEstimates: photoUsage?.used ?? 0
        )
    }

    public var remainingPhotoEstimates: Int {
        max(0, monthlyPhotoEstimateLimit - usedPhotoEstimates)
    }

    public var photoAnalysisUsage: MealMarkUsageSnapshot {
        MealMarkUsageSnapshot(
            feature: .photoAnalysis,
            limit: monthlyPhotoEstimateLimit,
            used: usedPhotoEstimates,
            resetAtMs: nil,
            entitlementRequired: tier == .free && remainingPhotoEstimates == 0
        )
    }

    public var summary: String {
        "\(tier.label): \(remainingPhotoEstimates) photo estimates left"
    }
}

public enum MealMarkPlusProductID: String, Codable, CaseIterable, Equatable, Sendable {
    case monthly = "dev.grain.foodwallet.plus.monthly"
    case yearly = "dev.grain.foodwallet.plus.yearly"

    public var label: String {
        switch self {
        case .monthly:
            return "MealMark Plus Monthly"
        case .yearly:
            return "MealMark Plus Yearly"
        }
    }

    public static func recognizes(_ productID: String) -> Bool {
        allCases.contains { $0.rawValue == productID }
    }
}

public enum MealMarkEntitlementSource: String, Codable, Equatable, Sendable {
    case none
    case defaultFree = "default_free"
    case localDev = "local_dev"
    case storeKit = "storekit"
}

public enum MealMarkUsageFeature: String, Codable, CaseIterable, Equatable, Sendable {
    case photoAnalysis = "photo_analysis"
    case foodSearch = "food_search"

    public var label: String {
        switch self {
        case .photoAnalysis:
            return "Photo analysis"
        case .foodSearch:
            return "Food search"
        }
    }
}

public struct MealMarkUsageSnapshot: Codable, Equatable, Sendable {
    public var feature: MealMarkUsageFeature
    public var limit: Int
    public var used: Int
    public var resetAtMs: Int64?
    public var entitlementRequired: Bool

    public init(
        feature: MealMarkUsageFeature,
        limit: Int,
        used: Int,
        resetAtMs: Int64? = nil,
        entitlementRequired: Bool = false
    ) {
        self.feature = feature
        self.limit = max(0, limit)
        self.used = max(0, used)
        self.resetAtMs = resetAtMs
        self.entitlementRequired = entitlementRequired
    }

    public var remaining: Int {
        max(0, limit - used)
    }

    public var isExhausted: Bool {
        used >= limit
    }

    private enum CodingKeys: String, CodingKey {
        case feature
        case limit
        case used
        case resetAtMs = "reset_at_ms"
        case entitlementRequired = "entitlement_required"
    }
}

public struct MealMarkEntitlement: Codable, Equatable, Sendable {
    public var tier: SubscriptionTier
    public var source: MealMarkEntitlementSource
    public var productID: String?
    public var originalTransactionID: String?
    public var effectiveAtMs: Int64?
    public var expiresAtMs: Int64?
    public var updatedAtMs: Int64?

    public init(
        tier: SubscriptionTier = .free,
        source: MealMarkEntitlementSource = .none,
        productID: String? = nil,
        originalTransactionID: String? = nil,
        effectiveAtMs: Int64? = nil,
        expiresAtMs: Int64? = nil,
        updatedAtMs: Int64? = nil
    ) {
        self.tier = tier
        self.source = source
        self.productID = productID
        self.originalTransactionID = originalTransactionID
        self.effectiveAtMs = effectiveAtMs
        self.expiresAtMs = expiresAtMs
        self.updatedAtMs = updatedAtMs
    }

    public static let free = MealMarkEntitlement()

    public static func storeKitPlus(
        productID: MealMarkPlusProductID,
        originalTransactionID: String,
        effectiveAtMs: Int64? = nil,
        expiresAtMs: Int64? = nil,
        updatedAtMs: Int64? = nil
    ) -> MealMarkEntitlement {
        MealMarkEntitlement(
            tier: .plus,
            source: .storeKit,
            productID: productID.rawValue,
            originalTransactionID: originalTransactionID,
            effectiveAtMs: effectiveAtMs,
            expiresAtMs: expiresAtMs,
            updatedAtMs: updatedAtMs
        )
    }

    public var isPlus: Bool {
        tier.isPlus
    }

    public func isActive(nowMs: Int64) -> Bool {
        guard let expiresAtMs else {
            return true
        }
        return expiresAtMs > nowMs
    }

    private enum CodingKeys: String, CodingKey {
        case tier
        case source
        case productID = "product_id"
        case originalTransactionID = "original_transaction_id"
        case effectiveAtMs = "effective_at_ms"
        case expiresAtMs = "expires_at_ms"
        case updatedAtMs = "updated_at_ms"
    }
}

private extension SubscriptionTier {
    func defaultMonthlyLimit(for feature: MealMarkUsageFeature) -> Int {
        switch (self, feature) {
        case (.free, .photoAnalysis):
            return 10
        case (.free, .foodSearch):
            return 500
        case (.pro, .photoAnalysis):
            return 500
        case (.pro, .foodSearch):
            return 10_000
        }
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
            detail: "AI estimates never become MealMark records until you save them."
        ),
        PrivacyPromise(
            title: "Safe summaries stay safe",
            detail: "Exports omit raw photos, protocol payloads, snapshots, and private trust material."
        ),
    ]
}
