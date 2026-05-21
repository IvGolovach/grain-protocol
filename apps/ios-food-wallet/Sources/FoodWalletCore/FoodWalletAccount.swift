import Foundation

public enum FoodWalletAccountStatus: String, Codable, Equatable, Sendable {
    case localOnly
    case signedIn
    case suspended
}

public struct FoodWalletAccountState: Codable, Equatable, Sendable {
    public var status: FoodWalletAccountStatus
    public var accountID: String?
    public var deviceID: String?
    public var entitlement: SubscriptionState
    public var updatedAt: Date

    public init(
        status: FoodWalletAccountStatus = .localOnly,
        accountID: String? = nil,
        deviceID: String? = nil,
        entitlement: SubscriptionState = .free,
        updatedAt: Date = Date()
    ) {
        self.status = status
        self.accountID = accountID
        self.deviceID = deviceID
        self.entitlement = entitlement
        self.updatedAt = updatedAt
    }

    public static let localOnly = FoodWalletAccountState()
}

public protocol FoodWalletSessionTokenStore: Sendable {
    func loadSessionToken() async -> String?
    func saveSessionToken(_ token: String?) async
}

public actor InMemoryFoodWalletSessionTokenStore: FoodWalletSessionTokenStore {
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func loadSessionToken() async -> String? {
        token
    }

    public func saveSessionToken(_ token: String?) async {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.token = trimmed.isEmpty ? nil : trimmed
    }
}

public struct FoodWalletSessionAuthorizationProvider: FoodAnalysisBrokerAuthorizationProvider {
    private let tokenStore: any FoodWalletSessionTokenStore

    public init(tokenStore: any FoodWalletSessionTokenStore) {
        self.tokenStore = tokenStore
    }

    public func bearerToken() async -> String? {
        await tokenStore.loadSessionToken()
    }
}
