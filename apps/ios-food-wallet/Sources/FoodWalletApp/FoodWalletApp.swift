import FoodWalletAppIntents
import FoodWalletCore
import SwiftUI

@main
struct FoodWalletAppMain: App {
    @StateObject private var store = FoodWalletStore()

    var body: some Scene {
        WindowGroup {
            FoodWalletRootView()
                .environmentObject(store)
        }
    }
}
