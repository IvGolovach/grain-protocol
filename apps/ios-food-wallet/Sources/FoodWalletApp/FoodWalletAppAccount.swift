import FoodWalletCore
import Foundation

#if canImport(Security)
import Security
#endif

actor KeychainFoodWalletSessionTokenStore: FoodWalletSessionTokenStore {
    private let service: String
    private let account: String

    init(service: String = "dev.grain.foodwallet.session", account: String = "mealmark-broker") {
        self.service = service
        self.account = account
    }

    func loadSessionToken() async -> String? {
        #if canImport(Security)
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
        #else
        return nil
        #endif
    }

    func saveSessionToken(_ token: String?) async {
        #if canImport(Security)
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            SecItemDelete(baseQuery() as CFDictionary)
            return
        }

        let data = Data(trimmed.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery()
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
        #endif
    }

    #if canImport(Security)
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    #endif
}

@MainActor
final class FoodWalletAppAccountManager: ObservableObject {
    @Published private(set) var accountState: FoodWalletAccountState = .localOnly
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let client: FoodWalletAccountBrokerClient?
    private let tokenStore: KeychainFoodWalletSessionTokenStore
    private let appAccountTokenStore: FoodWalletAppAccountTokenStore

    init(
        brokerBaseURL: URL?,
        tokenStore: KeychainFoodWalletSessionTokenStore,
        appAccountTokenStore: FoodWalletAppAccountTokenStore = FoodWalletAppAccountTokenStore()
    ) {
        self.tokenStore = tokenStore
        self.appAccountTokenStore = appAccountTokenStore
        if let brokerBaseURL {
            self.client = FoodWalletAccountBrokerClient(baseURL: brokerBaseURL, tokenStore: tokenStore)
        } else {
            self.client = nil
        }
    }

    var isConfigured: Bool {
        client != nil
    }

    func appAccountTokenForStoreKit() -> UUID {
        appAccountTokenStore.loadOrCreate()
    }

    func bootstrapIfNeeded(
        appVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        buildNumber: String? = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    ) async {
        guard let client else {
            accountState = .localOnly
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            if await tokenStore.loadSessionToken() != nil {
                do {
                    let response = try await client.account()
                    accountState = FoodWalletAccountState(profile: response.account)
                    errorMessage = nil
                    return
                } catch {
                    await tokenStore.saveSessionToken(nil)
                }
            }

            let appAccountToken = appAccountTokenStore.loadOrCreate()
            let request = FoodWalletAccountBootstrapRequest(
                deviceIDHash: appAccountToken.uuidString,
                appAccountToken: appAccountToken,
                appVersion: appVersion,
                buildNumber: buildNumber,
                localeIdentifier: Locale.autoupdatingCurrent.identifier,
                storefrontCountryCode: Locale.autoupdatingCurrent.region?.identifier,
                clientGeneratedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
            let response = try await client.bootstrap(request)
            accountState = FoodWalletAccountState(profile: response.account)
            errorMessage = nil
        } catch {
            accountState = .localOnly
            errorMessage = "MealMark account is unavailable. Local logging still works."
        }
    }

    func refreshAccount() async {
        guard let client else { return }
        do {
            let response = try await client.account()
            accountState = FoodWalletAccountState(profile: response.account)
            errorMessage = nil
        } catch {
            errorMessage = "MealMark could not refresh your account."
        }
    }

    func ingestStoreKitTransaction(jwsRepresentation: String) async throws -> FoodWalletStoreKitTransactionResponse {
        guard let client else {
            throw FoodAnalysisBrokerClientError.networkUnavailable
        }
        let response = try await client.ingestStoreKitTransaction(
            FoodWalletStoreKitTransactionRequest(signedTransactionInfo: jwsRepresentation)
        )
        accountState = FoodWalletAccountState(profile: response.account)
        errorMessage = nil
        return response
    }

    func deleteCloudAccount() async {
        guard let client else { return }
        do {
            try await client.deleteAccount()
            appAccountTokenStore.reset()
            accountState = .localOnly
            errorMessage = nil
        } catch {
            errorMessage = "MealMark could not delete the cloud account right now."
        }
    }
}

struct FoodWalletAppAccountTokenStore: Sendable {
    private let defaultsKey: String
    private let keychainService: String
    private let keychainAccount: String

    init(
        defaultsKey: String = "grain.food-wallet.app-account-token.v1",
        keychainService: String = "dev.grain.foodwallet.storekit",
        keychainAccount: String = "mealmark-app-account-token"
    ) {
        self.defaultsKey = defaultsKey
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
    }

    func loadOrCreate() -> UUID {
        if let uuid = loadFromKeychain() {
            return uuid
        }
        if let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
           let uuid = UUID(uuidString: rawValue) {
            saveToKeychain(uuid)
            return uuid
        }
        let uuid = UUID()
        saveToKeychain(uuid)
        UserDefaults.standard.set(uuid.uuidString, forKey: defaultsKey)
        return uuid
    }

    func reset() {
        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func loadFromKeychain() -> UUID? {
        #if canImport(Security)
        var query = baseKeychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let rawValue = String(data: data, encoding: .utf8) else {
            return nil
        }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        #else
        return nil
        #endif
    }

    private func saveToKeychain(_ uuid: UUID) {
        #if canImport(Security)
        let value = uuid.uuidString.lowercased()
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseKeychainQuery() as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseKeychainQuery()
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
        #endif
    }

    private func deleteFromKeychain() {
        #if canImport(Security)
        SecItemDelete(baseKeychainQuery() as CFDictionary)
        #endif
    }

    #if canImport(Security)
    private func baseKeychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }
    #endif
}
