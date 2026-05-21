import Foundation
import StoreKit

#if os(iOS)
import UIKit
#endif

@MainActor
final class MealMarkPlusStore: ObservableObject {
    static let productIDs = [
        "dev.grain.foodwallet.plus.monthly",
        "dev.grain.foodwallet.plus.yearly",
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var unavailableMessage: String?
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var isRestoring = false
    @Published private(set) var isOpeningManageSubscriptions = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var isPlusActive: Bool {
        !activeProductIDs.isEmpty
    }

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    func start(accountManager: FoodWalletAppAccountManager?) async {
        listenForTransactionUpdatesIfNeeded(accountManager: accountManager)
        await refresh(accountManager: accountManager)
    }

    func refresh(accountManager: FoodWalletAppAccountManager? = nil) async {
        await loadProducts()
        await refreshEntitlements(accountManager: accountManager)
    }

    func purchase(_ product: Product, accountManager: FoodWalletAppAccountManager?) async {
        guard purchasingProductID == nil else { return }

        statusMessage = nil
        errorMessage = nil
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let options: Set<Product.PurchaseOption>
            if let accountManager {
                options = [.appAccountToken(accountManager.appAccountTokenForStoreKit())]
            } else {
                options = []
            }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                guard let payload = verifiedTransactionPayload(from: verification) else {
                    errorMessage = "MealMark Plus could not verify this purchase."
                    return
                }
                if let accountManager {
                    do {
                        _ = try await accountManager.ingestStoreKitTransaction(
                            jwsRepresentation: payload.jwsRepresentation
                        )
                    } catch {
                        errorMessage = "Apple verified the purchase, but MealMark could not activate Plus on the server."
                        return
                    }
                }
                await payload.transaction.finish()
                await refreshEntitlements(accountManager: accountManager)
                statusMessage = "MealMark Plus is active."
            case .pending:
                statusMessage = "Purchase pending. MealMark Plus will activate after Apple approves it."
            case .userCancelled:
                break
            @unknown default:
                statusMessage = "The purchase did not finish. Please try again."
            }
        } catch {
            errorMessage = purchaseErrorMessage(error)
        }
    }

    func restorePurchases(accountManager: FoodWalletAppAccountManager?) async {
        guard !isRestoring else { return }

        statusMessage = nil
        errorMessage = nil
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements(accountManager: accountManager)
            statusMessage = isPlusActive ? "MealMark Plus was restored." : "No active MealMark Plus subscription was found."
        } catch {
            errorMessage = "MealMark could not restore purchases. Please try again."
        }
    }

    func manageSubscriptions() async {
        guard !isOpeningManageSubscriptions else { return }

        statusMessage = nil
        errorMessage = nil
        isOpeningManageSubscriptions = true
        defer { isOpeningManageSubscriptions = false }

        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            errorMessage = "MealMark could not open Apple subscription management from this scene."
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            errorMessage = "MealMark could not open Apple subscription management."
        }
        #else
        errorMessage = "Apple subscription management is available on iPhone."
        #endif
    }

    private func listenForTransactionUpdatesIfNeeded(accountManager: FoodWalletAppAccountManager?) {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handleTransactionUpdate(update, accountManager: accountManager)
            }
        }
    }

    private func loadProducts() async {
        isLoadingProducts = true
        unavailableMessage = nil
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted(by: productSort)
            if products.isEmpty {
                unavailableMessage = "MealMark Plus subscription options are not available in this build."
            }
        } catch {
            products = []
            unavailableMessage = "MealMark Plus subscription options could not be loaded."
        }
    }

    private func refreshEntitlements(accountManager: FoodWalletAppAccountManager? = nil) async {
        var activeIDs = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            guard let payload = verifiedTransactionPayload(from: entitlement),
                  Self.productIDs.contains(payload.transaction.productID),
                  payload.transaction.revocationDate == nil
            else {
                continue
            }
            activeIDs.insert(payload.transaction.productID)
            if let accountManager {
                do {
                    _ = try await accountManager.ingestStoreKitTransaction(
                        jwsRepresentation: payload.jwsRepresentation
                    )
                } catch {
                    errorMessage = "MealMark could not sync this App Store entitlement with the server."
                }
            }
        }
        activeProductIDs = activeIDs
    }

    private func handleTransactionUpdate(
        _ update: VerificationResult<Transaction>,
        accountManager: FoodWalletAppAccountManager?
    ) async {
        guard let payload = verifiedTransactionPayload(from: update) else {
            errorMessage = "MealMark Plus received an unverified App Store update."
            return
        }

        if let accountManager {
            do {
                _ = try await accountManager.ingestStoreKitTransaction(
                    jwsRepresentation: payload.jwsRepresentation
                )
            } catch {
                errorMessage = "MealMark could not sync this App Store update with the server."
            }
        }

        await payload.transaction.finish()
        await refreshEntitlements(accountManager: accountManager)
    }

    private func verifiedTransactionPayload(
        from verification: VerificationResult<Transaction>
    ) -> (transaction: Transaction, jwsRepresentation: String)? {
        switch verification {
        case .verified(let transaction):
            return (transaction, verification.jwsRepresentation)
        case .unverified:
            return nil
        }
    }

    private func productSort(_ lhs: Product, _ rhs: Product) -> Bool {
        productRank(lhs.id) < productRank(rhs.id)
    }

    private func productRank(_ productID: String) -> Int {
        Self.productIDs.firstIndex(of: productID) ?? Self.productIDs.count
    }

    private func purchaseErrorMessage(_ error: Error) -> String {
        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return "This MealMark Plus option is not available right now."
            case .purchaseNotAllowed:
                return "Purchases are not allowed on this Apple ID or device."
            case .ineligibleForOffer:
                return "This Apple ID is not eligible for the selected offer."
            default:
                return "MealMark could not complete the purchase."
            }
        }

        return "MealMark could not complete the purchase."
    }
}
