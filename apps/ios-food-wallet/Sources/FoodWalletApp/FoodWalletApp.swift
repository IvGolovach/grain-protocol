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
    private static let deviceSmokeArgument = "--grain-device-smoke"
    private static let uiTestPhotoFlowArgument = "--grain-ui-test-photo-flow"

    @MainActor
    static func makeStore() -> FoodWalletStore {
        FoodWalletStore(analysisClient: makeAnalysisClient())
    }

    private static func makeAnalysisClient() -> any FoodAnalysisClient {
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
}
