import FoodWalletAppIntents
import FoodWalletCore
import Foundation
import GrainFoodWallet
import SwiftUI

@main
struct FoodWalletAppMain: App {
    @StateObject private var store = FoodWalletAppConfiguration.makeStore()

    var body: some Scene {
        WindowGroup {
            FoodWalletRootView()
                .environmentObject(store)
                .task {
                    await runDeviceSmokeIfRequested()
                }
        }
    }

    @MainActor
    private func runDeviceSmokeIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--grain-device-smoke") else {
            return
        }

        let smokeStore = FoodWalletStore(
            analysisClient: MockFoodAnalysisClient(),
            searchClient: MockBrokerFoodSearchClient()
        )
        let result = await smokeStore.runDeviceSmoke()
        if result.passed {
            print("GRAIN_IOS_FOOD_WALLET_DEVICE_SMOKE: PASS entries=\(result.entryCount) kcal=\(result.totalKcal)")
            Foundation.exit(0)
        }

        fputs("GRAIN_IOS_FOOD_WALLET_DEVICE_SMOKE: FAIL \(result.reason)\n", stderr)
        Foundation.exit(1)
    }
}

private enum FoodWalletAppConfiguration {
    private static let brokerEndpointEnvironmentKey = "GRAIN_FOOD_ANALYSIS_BROKER_URL"
    private static let brokerTokenEnvironmentKey = "GRAIN_FOOD_BROKER_DEV_TOKEN"
    private static let deviceSmokeArgument = "--grain-device-smoke"
    private static let uiTestPhotoFlowArgument = "--grain-ui-test-photo-flow"
    private static let uiTestDelayedPhotoFlowArgument = "--grain-ui-test-delayed-photo-flow"
    private static let uiTestNoFoodPhotoFlowArgument = "--grain-ui-test-no-food-photo-flow"
    private static let uiTestFailingPhotoFlowArgument = "--grain-ui-test-failing-photo-flow"
    private static let uiTestResetFoodWalletStorageArgument = "--grain-ui-test-reset-food-wallet-storage"
    private static let uiTestResetPersonalIngredientsArgument = "--grain-ui-test-reset-personal-ingredients"
    private static let uiTestAnalysisDelayArgument = "--grain-analysis-delay-ms"

    @MainActor
    static func makeStore() -> FoodWalletStore {
        if ProcessInfo.processInfo.arguments.contains(uiTestResetPersonalIngredientsArgument) {
            FoodWalletUserLibraryStore.remove()
        }
        if ProcessInfo.processInfo.arguments.contains(uiTestResetFoodWalletStorageArgument) {
            FoodWalletLocalLedgerStore.remove()
        }
        let userLibrary = FoodWalletUserLibraryStore.load()

        return FoodWalletStore(
            analysisClient: makeAnalysisClient(),
            searchClient: makeFoodSearchClient(),
            entries: FoodWalletLocalLedgerStore.loadEntries(),
            privacy: FoodWalletPrivacyPreferenceStore.load(),
            savedTemplates: userLibrary.templates,
            savedRecipes: userLibrary.recipes,
            personalIngredients: userLibrary.personalIngredients,
            onEntriesChange: FoodWalletLocalLedgerStore.save,
            onPersonalIngredientsChange: { _ in },
            onUserLibraryChange: FoodWalletUserLibraryStore.save,
            onPrivacyChange: FoodWalletPrivacyPreferenceStore.save,
            onEntriesReload: FoodWalletLocalLedgerStore.loadEntries
        )
    }

    private static func makeAnalysisClient() -> any FoodAnalysisClient {
        if ProcessInfo.processInfo.arguments.contains(uiTestDelayedPhotoFlowArgument) {
            return DelayedFoodAnalysisClient(delayNanoseconds: uiTestDelayNanoseconds())
        }
        if ProcessInfo.processInfo.arguments.contains(uiTestNoFoodPhotoFlowArgument) {
            return NoFoodFoodAnalysisClient()
        }
        if ProcessInfo.processInfo.arguments.contains(uiTestFailingPhotoFlowArgument) {
            return UnavailableFoodAnalysisClient()
        }
        if ProcessInfo.processInfo.arguments.contains(uiTestPhotoFlowArgument) ||
            ProcessInfo.processInfo.arguments.contains(deviceSmokeArgument) {
            return MockFoodAnalysisClient()
        }

        guard
            let endpointValue = configuredBrokerEndpoint(),
            let endpoint = URL(string: endpointValue),
            endpoint.scheme != nil,
            endpoint.host != nil,
            brokerEndpointIsAllowed(endpoint)
        else {
            return UnavailableFoodAnalysisClient()
        }
        guard let brokerToken = configuredBrokerToken() else {
            return UnavailableFoodAnalysisClient()
        }

        return FoodAnalysisBrokerClient(
            endpoint: analysisEndpoint(from: endpoint),
            bearerToken: brokerToken
        )
    }

    private static func makeFoodSearchClient() -> (any BrokerFoodSearchClient)? {
        if ProcessInfo.processInfo.arguments.contains("--grain-ui-test-barcode-flow") {
            return MockBrokerFoodSearchClient()
        }

        guard
            let endpointValue = configuredBrokerEndpoint(),
            let endpoint = URL(string: endpointValue),
            endpoint.scheme != nil,
            endpoint.host != nil,
            brokerEndpointIsAllowed(endpoint)
        else {
            return nil
        }

        return FoodAnalysisBrokerClient(
            analysisEndpoint: analysisEndpoint(from: endpoint),
            searchEndpoint: searchEndpoint(from: endpoint),
            bearerToken: configuredBrokerToken()
        )
    }

    private static func configuredBrokerEndpoint() -> String? {
        if let value = ProcessInfo.processInfo.environment[brokerEndpointEnvironmentKey], !value.isEmpty {
            return value
        }
        return Bundle.main.object(forInfoDictionaryKey: brokerEndpointEnvironmentKey) as? String
    }

    private static func configuredBrokerToken() -> String? {
        usableConfiguredValue(ProcessInfo.processInfo.environment[brokerTokenEnvironmentKey])
    }

    private static func brokerEndpointIsAllowed(_ endpoint: URL) -> Bool {
        guard let scheme = endpoint.scheme?.lowercased(), let host = endpoint.host else {
            return false
        }
        if scheme == "https" {
            return true
        }
        if scheme == "http" {
            return isLoopbackHost(host) || configuredBrokerToken() != nil
        }
        return false
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "localhost" || normalized == "::1" || normalized.hasPrefix("127.")
    }

    private static func usableConfiguredValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }

    private static func analysisEndpoint(from endpoint: URL) -> URL {
        if endpoint.path == "" || endpoint.path == "/" {
            return endpoint.appendingPathComponent("v1/food/analyze-photo")
        }
        return endpoint
    }

    private static func searchEndpoint(from endpoint: URL) -> URL {
        if endpoint.path == "" || endpoint.path == "/" {
            return endpoint.appendingPathComponent("v1/food/search")
        }
        if endpoint.path.hasSuffix("/analyze-photo") {
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
            components?.path = String(endpoint.path.dropLast("/analyze-photo".count)) + "/search"
            return components?.url ?? endpoint
        }
        return endpoint
    }

    private static func uiTestDelayNanoseconds() -> UInt64 {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let delayIndex = arguments.firstIndex(of: uiTestAnalysisDelayArgument),
            arguments.indices.contains(delayIndex + 1),
            let delayMilliseconds = UInt64(arguments[delayIndex + 1])
        else {
            return 900_000_000
        }
        return delayMilliseconds * 1_000_000
    }

}

private enum FoodWalletPrivacyPreferenceStore {
    private static let defaultsKey = "grain.food-wallet.ai-photo-consent.v1"

    static func load() -> PrivacyConsentState {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let state = PrivacyConsentState(rawValue: rawValue) else {
            return .notRequested
        }
        return state
    }

    static func save(_ state: PrivacyConsentState) {
        UserDefaults.standard.set(state.rawValue, forKey: defaultsKey)
    }
}

private enum FoodWalletUserLibraryStore {
    private static let defaultsKey = "grain.food-wallet.user-library.v1"
    private static let legacyPersonalIngredientsDefaultsKey = "grain.food-wallet.personal-ingredients.v1"

    static func load() -> FoodWalletUserLibraryState {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let state = try? FoodWalletUserLibraryCodec.decode(data) {
            return state
        }
        if let data = UserDefaults.standard.data(forKey: legacyPersonalIngredientsDefaultsKey),
           let state = try? FoodWalletUserLibraryCodec.decode(data) {
            save(state)
            UserDefaults.standard.removeObject(forKey: legacyPersonalIngredientsDefaultsKey)
            return state
        }
        return FoodWalletUserLibraryState()
    }

    static func save(_ state: FoodWalletUserLibraryState) {
        guard !state.isEmpty else {
            remove()
            return
        }
        guard let data = try? FoodWalletUserLibraryCodec.encode(state) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: legacyPersonalIngredientsDefaultsKey)
    }

    static func remove() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: legacyPersonalIngredientsDefaultsKey)
    }
}

enum FoodWalletLocalLedgerStore {
    private static let defaultsKey = "grain.food-wallet.local-ledger.v1"

    static var hasBackup: Bool {
        !loadEntries().isEmpty
    }

    static func loadEntries() -> [FoodIntakeEntry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return []
        }
        return (try? FoodWalletLocalLedgerCodec.decodeEntries(data)) ?? []
    }

    @MainActor
    static func save(_ entries: [FoodIntakeEntry]) {
        guard !entries.isEmpty else {
            remove()
            return
        }
        guard let data = try? FoodWalletLocalLedgerCodec.encodeEntries(entries) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func loadBundle() -> FoodWalletExportBundle? {
        let entries = loadEntries()
        guard !entries.isEmpty else {
            return nil
        }
        let userLibrary = FoodWalletUserLibraryStore.load()
        return try? FoodWalletExportFactory.portableBundle(
            entries: entries,
            templates: userLibrary.templates,
            recipes: userLibrary.recipes,
            generatedAt: Date(),
            personalFoods: userLibrary.personalIngredients
        )
    }

    static func remove() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

private struct DelayedFoodAnalysisClient: FoodAnalysisClient {
    var delayNanoseconds: UInt64

    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(example: example)
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(photo: photo)
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(photoPayload: photoPayload)
    }
}

private struct UnavailableFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw FoodWalletAppConfigurationError.analysisUnavailable
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw FoodWalletAppConfigurationError.analysisUnavailable
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw FoodWalletAppConfigurationError.analysisUnavailable
    }
}

private struct NoFoodFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    private func noFoodError() -> FoodAnalysisBrokerClientError {
        .brokerError(
            code: "NO_FOOD_DETECTED",
            message: "The image shows a desk setup with a monitor, cables, docking station, and chair; no food, drink, or readable nutrition label is visible.",
            status: 422
        )
    }
}

private enum FoodWalletAppConfigurationError: Error {
    case analysisUnavailable
}
