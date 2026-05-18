import FoodWalletAppIntents
import FoodWalletCore
import Foundation
import SwiftUI

@main
struct FoodWalletAppMain: App {
    @StateObject private var store = FoodWalletStore()

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
