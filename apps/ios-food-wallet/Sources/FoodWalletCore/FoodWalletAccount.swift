import Foundation

public enum FoodWalletAccountStatus: String, Codable, Equatable, Sendable {
    case localOnly
    case active
    case signedIn
    case suspended
    case deleted
}

public struct FoodWalletAccountState: Codable, Equatable, Sendable {
    public var status: FoodWalletAccountStatus
    public var accountID: String?
    public var deviceID: String?
    public var entitlement: SubscriptionState
    public var usage: [MealMarkUsageSnapshot]
    public var updatedAt: Date

    public init(
        status: FoodWalletAccountStatus = .localOnly,
        accountID: String? = nil,
        deviceID: String? = nil,
        entitlement: SubscriptionState = .free,
        usage: [MealMarkUsageSnapshot] = [],
        updatedAt: Date = Date()
    ) {
        self.status = status
        self.accountID = accountID
        self.deviceID = deviceID
        self.entitlement = entitlement
        self.usage = usage
        self.updatedAt = updatedAt
    }

    public init(profile: FoodWalletAccountProfile, updatedAt: Date = Date()) {
        self.init(
            status: profile.status,
            accountID: profile.accountID,
            deviceID: profile.deviceID,
            entitlement: SubscriptionState(entitlement: profile.entitlement, usage: profile.usage),
            usage: profile.usage,
            updatedAt: updatedAt
        )
    }

    public static let localOnly = FoodWalletAccountState()
}

public enum FoodWalletStoreKitEnvironment: String, Codable, CaseIterable, Equatable, Sendable {
    case sandbox = "Sandbox"
    case production = "Production"
    case xcode = "Xcode"
}

public enum FoodWalletAccountClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingSessionToken

    public var description: String {
        switch self {
        case .missingSessionToken:
            return "session token is required for this account request"
        }
    }
}

public struct FoodWalletAccountHTTPClientRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var requiresSessionToken: Bool
    public var body: Data?

    public init(
        method: String,
        path: String,
        requiresSessionToken: Bool,
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.requiresSessionToken = requiresSessionToken
        self.body = body
    }

    public func urlRequest(baseURL: URL, sessionToken: String? = nil) throws -> URLRequest {
        if requiresSessionToken {
            let trimmed = sessionToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                throw FoodWalletAccountClientError.missingSessionToken
            }
        }

        var request = URLRequest(url: Self.endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if let token = sessionToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func endpointURL(baseURL: URL, path: String) -> URL {
        let normalizedEndpointPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL.appendingPathComponent(normalizedEndpointPath)
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combinedPath = [basePath, normalizedEndpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/\(combinedPath)"
        return components.url ?? baseURL.appendingPathComponent(normalizedEndpointPath)
    }
}

public struct FoodWalletAccountBootstrapRequest: Codable, Equatable, Sendable {
    public var deviceIDHash: String
    public var appAccountToken: UUID
    public var platform: String
    public var appBundleID: String
    public var appVersion: String?
    public var buildNumber: String?
    public var localeIdentifier: String?
    public var storefrontCountryCode: String?
    public var clientGeneratedAtMs: Int64?

    public init(
        deviceIDHash: String,
        appAccountToken: UUID,
        platform: String = "ios",
        appBundleID: String = "dev.grain.foodwallet",
        appVersion: String? = nil,
        buildNumber: String? = nil,
        localeIdentifier: String? = nil,
        storefrontCountryCode: String? = nil,
        clientGeneratedAtMs: Int64? = nil
    ) {
        self.deviceIDHash = deviceIDHash
        self.appAccountToken = appAccountToken
        self.platform = platform
        self.appBundleID = appBundleID
        self.appVersion = Self.clean(appVersion)
        self.buildNumber = Self.clean(buildNumber)
        self.localeIdentifier = Self.clean(localeIdentifier)
        self.storefrontCountryCode = Self.clean(storefrontCountryCode)
        self.clientGeneratedAtMs = clientGeneratedAtMs
    }

    public func clientRequest(encoder: JSONEncoder = JSONEncoder()) throws -> FoodWalletAccountHTTPClientRequest {
        FoodWalletAccountHTTPClientRequest(
            method: "POST",
            path: "/v1/auth/bootstrap",
            requiresSessionToken: false,
            body: try encoder.encode(self)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case deviceIDHash = "device_id_hash"
        case appAccountToken = "app_account_token"
        case platform
        case appBundleID = "app_bundle_id"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case localeIdentifier = "locale_identifier"
        case storefrontCountryCode = "storefront_country_code"
        case clientGeneratedAtMs = "client_generated_at_ms"
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct FoodWalletAccountMeRequest: Equatable, Sendable {
    public init() {}

    public func clientRequest() -> FoodWalletAccountHTTPClientRequest {
        FoodWalletAccountHTTPClientRequest(
            method: "GET",
            path: "/v1/account/me",
            requiresSessionToken: true
        )
    }
}

public struct FoodWalletStoreKitTransactionRequest: Codable, Equatable, Sendable {
    public var signedTransactionInfo: String

    public init(signedTransactionInfo: String) {
        self.signedTransactionInfo = signedTransactionInfo
    }

    public func clientRequest(encoder: JSONEncoder = JSONEncoder()) throws -> FoodWalletAccountHTTPClientRequest {
        FoodWalletAccountHTTPClientRequest(
            method: "POST",
            path: "/v1/storekit/transactions",
            requiresSessionToken: true,
            body: try encoder.encode(self)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case signedTransactionInfo = "signed_transaction_info"
    }
}

public struct FoodWalletAccountProfile: Codable, Equatable, Sendable {
    public var accountID: String
    public var deviceID: String?
    public var status: FoodWalletAccountStatus
    public var entitlement: MealMarkEntitlement
    public var usage: [MealMarkUsageSnapshot]

    public init(
        accountID: String,
        deviceID: String? = nil,
        status: FoodWalletAccountStatus = .active,
        entitlement: MealMarkEntitlement = .free,
        usage: [MealMarkUsageSnapshot] = []
    ) {
        self.accountID = accountID
        self.deviceID = deviceID
        self.status = status
        self.entitlement = entitlement
        self.usage = usage
    }

    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case deviceID = "device_id"
        case status
        case entitlement
        case usage
    }
}

public struct FoodWalletAccountBootstrapResponse: Decodable, Equatable, Sendable {
    public var account: FoodWalletAccountProfile
    public var sessionToken: String

    public init(account: FoodWalletAccountProfile, sessionToken: String) {
        self.account = account
        self.sessionToken = sessionToken
    }

    private enum CodingKeys: String, CodingKey {
        case account
        case entitlement
        case usage
        case session
        case sessionToken = "session_token"
    }

    private enum SessionCodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawAccount = try container.decode(AccountProfileWire.self, forKey: .account)
        let entitlement = (try? container.decode(MealMarkEntitlement.self, forKey: .entitlement)) ?? rawAccount.entitlement ?? .free
        let usage = (try? container.decode([MealMarkUsageSnapshot].self, forKey: .usage)) ?? rawAccount.usage ?? []
        self.account = rawAccount.profile(entitlement: entitlement, usage: usage)
        if let directToken = try? container.decode(String.self, forKey: .sessionToken) {
            self.sessionToken = directToken
        } else {
            let session = try container.nestedContainer(keyedBy: SessionCodingKeys.self, forKey: .session)
            self.sessionToken = try session.decode(String.self, forKey: .accessToken)
        }
    }
}

public struct FoodWalletAccountMeResponse: Decodable, Equatable, Sendable {
    public var account: FoodWalletAccountProfile

    public init(account: FoodWalletAccountProfile) {
        self.account = account
    }

    private enum CodingKeys: String, CodingKey {
        case account
        case entitlement
        case usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawAccount = try container.decode(AccountProfileWire.self, forKey: .account)
        let entitlement = (try? container.decode(MealMarkEntitlement.self, forKey: .entitlement)) ?? rawAccount.entitlement ?? .free
        let usage = (try? container.decode([MealMarkUsageSnapshot].self, forKey: .usage)) ?? rawAccount.usage ?? []
        self.account = rawAccount.profile(entitlement: entitlement, usage: usage)
    }
}

public struct FoodWalletStoreKitTransactionResponse: Decodable, Equatable, Sendable {
    public var account: FoodWalletAccountProfile
    public var entitlement: MealMarkEntitlement

    public init(account: FoodWalletAccountProfile, entitlement: MealMarkEntitlement) {
        self.account = account
        self.entitlement = entitlement
    }

    private enum CodingKeys: String, CodingKey {
        case account
        case entitlement
        case usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entitlement = try container.decode(MealMarkEntitlement.self, forKey: .entitlement)
        if let rawAccount = try? container.decode(AccountProfileWire.self, forKey: .account) {
            let usage = (try? container.decode([MealMarkUsageSnapshot].self, forKey: .usage)) ?? rawAccount.usage ?? []
            self.account = rawAccount.profile(entitlement: entitlement, usage: usage)
        } else {
            self.account = FoodWalletAccountProfile(accountID: "", entitlement: entitlement)
        }
        self.entitlement = entitlement
    }
}

private struct AccountProfileWire: Decodable {
    var accountID: String
    var deviceID: String?
    var status: FoodWalletAccountStatus
    var entitlement: MealMarkEntitlement?
    var usage: [MealMarkUsageSnapshot]?

    func profile(entitlement: MealMarkEntitlement, usage: [MealMarkUsageSnapshot]) -> FoodWalletAccountProfile {
        FoodWalletAccountProfile(
            accountID: accountID,
            deviceID: deviceID,
            status: status,
            entitlement: entitlement,
            usage: usage
        )
    }

    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case deviceID = "device_id"
        case status
        case entitlement
        case usage
    }
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

public struct FoodWalletAccountBrokerClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: any FoodWalletSessionTokenStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: URL,
        tokenStore: any FoodWalletSessionTokenStore,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    public func bootstrap(_ request: FoodWalletAccountBootstrapRequest) async throws -> FoodWalletAccountBootstrapResponse {
        let clientRequest = try request.clientRequest(encoder: encoder)
        let response: FoodWalletAccountBootstrapResponse = try await send(clientRequest)
        await tokenStore.saveSessionToken(response.sessionToken)
        return response
    }

    public func refreshSession() async throws -> FoodWalletAccountBootstrapResponse {
        let clientRequest = FoodWalletAccountHTTPClientRequest(
            method: "POST",
            path: "/v1/auth/refresh",
            requiresSessionToken: true
        )
        let response: FoodWalletAccountBootstrapResponse = try await send(clientRequest)
        await tokenStore.saveSessionToken(response.sessionToken)
        return response
    }

    public func account() async throws -> FoodWalletAccountMeResponse {
        try await send(FoodWalletAccountMeRequest().clientRequest())
    }

    public func ingestStoreKitTransaction(_ request: FoodWalletStoreKitTransactionRequest) async throws -> FoodWalletStoreKitTransactionResponse {
        try await send(request.clientRequest(encoder: encoder))
    }

    public func logout() async throws {
        let clientRequest = FoodWalletAccountHTTPClientRequest(
            method: "POST",
            path: "/v1/auth/logout",
            requiresSessionToken: true
        )
        let _: EmptyBrokerResponse = try await send(clientRequest)
        await tokenStore.saveSessionToken(nil)
    }

    public func deleteAccount() async throws {
        let clientRequest = FoodWalletAccountHTTPClientRequest(
            method: "POST",
            path: "/v1/account/delete",
            requiresSessionToken: true
        )
        let _: EmptyBrokerResponse = try await send(clientRequest)
        await tokenStore.saveSessionToken(nil)
    }

    private func send<ResponseBody: Decodable>(_ clientRequest: FoodWalletAccountHTTPClientRequest) async throws -> ResponseBody {
        let token = await tokenStore.loadSessionToken()
        var urlRequest = try clientRequest.urlRequest(baseURL: baseURL, sessionToken: token)
        urlRequest.timeoutInterval = 20

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw FoodAnalysisBrokerClient.mapPublicTransportError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FoodAnalysisBrokerClient.decodePublicBrokerError(from: data, status: httpResponse.statusCode)
        }
        return try decoder.decode(ResponseBody.self, from: data)
    }
}

private struct EmptyBrokerResponse: Decodable {
    var ok: Bool
}
