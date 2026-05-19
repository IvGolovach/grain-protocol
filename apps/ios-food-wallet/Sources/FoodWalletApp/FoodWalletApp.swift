import FoodWalletAppIntents
import FoodWalletCore
import Foundation
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

        let result = await store.runDeviceSmoke()
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
    private static let personalIngredientsDefaultsKey = "grain.food-wallet.personal-ingredients.v1"
    private static let deviceSmokeArgument = "--grain-device-smoke"
    private static let uiTestPhotoFlowArgument = "--grain-ui-test-photo-flow"
    private static let uiTestDelayedPhotoFlowArgument = "--grain-ui-test-delayed-photo-flow"
    private static let uiTestFailingPhotoFlowArgument = "--grain-ui-test-failing-photo-flow"
    private static let uiTestResetPersonalIngredientsArgument = "--grain-ui-test-reset-personal-ingredients"
    private static let uiTestAnalysisDelayArgument = "--grain-analysis-delay-ms"

    @MainActor
    static func makeStore() -> FoodWalletStore {
        if ProcessInfo.processInfo.arguments.contains(uiTestResetPersonalIngredientsArgument) {
            UserDefaults.standard.removeObject(forKey: personalIngredientsDefaultsKey)
        }
        return FoodWalletStore(
            analysisClient: makeAnalysisClient(),
            personalIngredients: loadPersonalIngredients(),
            onPersonalIngredientsChange: savePersonalIngredients
        )
    }

    private static func makeAnalysisClient() -> any FoodAnalysisClient {
        if ProcessInfo.processInfo.arguments.contains(uiTestDelayedPhotoFlowArgument) {
            return DelayedFoodAnalysisClient(delayNanoseconds: uiTestDelayNanoseconds())
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
            endpoint.host != nil
        else {
            return MockFoodAnalysisClient()
        }

        return FoodAnalysisBrokerClient(endpoint: analysisEndpoint(from: endpoint))
    }

    private static func configuredBrokerEndpoint() -> String? {
        if let value = ProcessInfo.processInfo.environment[brokerEndpointEnvironmentKey], !value.isEmpty {
            return value
        }
        return Bundle.main.object(forInfoDictionaryKey: brokerEndpointEnvironmentKey) as? String
    }

    private static func analysisEndpoint(from endpoint: URL) -> URL {
        if endpoint.path == "" || endpoint.path == "/" {
            return endpoint.appendingPathComponent("v1/food/analyze-photo")
        }
        return endpoint
    }

    private static func loadPersonalIngredients() -> [PersonalFoodIngredient] {
        guard let data = UserDefaults.standard.data(forKey: personalIngredientsDefaultsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([PersonalFoodIngredient].self, from: data)) ?? []
    }

    @MainActor
    private static func savePersonalIngredients(_ ingredients: [PersonalFoodIngredient]) {
        guard !ingredients.isEmpty else {
            UserDefaults.standard.removeObject(forKey: personalIngredientsDefaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(ingredients) else {
            return
        }
        UserDefaults.standard.set(data, forKey: personalIngredientsDefaultsKey)
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

private enum FoodWalletAppConfigurationError: Error {
    case analysisUnavailable
}
