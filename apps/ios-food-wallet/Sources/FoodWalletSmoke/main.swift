import FoodWalletCore
import Foundation

@main
struct FoodWalletSmoke {
    static func main() async {
        let store = FoodWalletStore()
        store.grantAIConsent()
        await store.analyze(photo: .uiTestFujiApple)
        guard store.currentCandidate?.primaryLabel == "Fuji apple" else {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_ANALYSIS\n", stderr)
            Foundation.exit(1)
        }
        guard store.currentDraft != nil else {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_DRAFT\n", stderr)
            Foundation.exit(1)
        }
        guard store.currentCandidate?.macronutrients.carbohydrateGrams == 27 else {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_MACROS\n", stderr)
            Foundation.exit(1)
        }
        store.confirmDraft()
        guard store.entries.count == 1 else {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_CONFIRM\n", stderr)
            Foundation.exit(1)
        }
        guard store.todayEntries.count == 1 else {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_TODAY\n", stderr)
            Foundation.exit(1)
        }
        let summary = String(describing: store.safeSummary)
        let forbidden = ["rawPhoto", "photoBytes", "COSE", "CBOR", "snapshot", "privateKey", "trustPub", "GR1"]
        for token in forbidden where summary.localizedCaseInsensitiveContains(token) {
            fputs("IOS_FOOD_WALLET_SMOKE_ERR_UNSAFE_SUMMARY: \(token)\n", stderr)
            Foundation.exit(1)
        }
        print("IOS_FOOD_WALLET_SMOKE: PASS entries=\(store.entries.count) kcal=\(store.safeSummary.totals.sumMeanKcal)")
    }
}
