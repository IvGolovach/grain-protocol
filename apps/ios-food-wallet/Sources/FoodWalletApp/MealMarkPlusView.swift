import FoodWalletCore
import StoreKit
import SwiftUI

struct MealMarkPlusView: View {
    var subscription: SubscriptionState
    @ObservedObject var accountManager: FoodWalletAppAccountManager
    @ObservedObject var storeKit: MealMarkPlusStore

    var body: some View {
        List {
            heroSection
            usageSection
            productsSection
            controlsSection
            accountSection
            valueSection
            termsSection
        }
        .navigationTitle("Plus")
        .refreshable {
            await accountManager.refreshAccount()
            await storeKit.refresh(accountManager: accountManager)
        }
    }

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.accentColor))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("MealMark Plus")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("More room for photo drafts, deeper mixed-meal review, weekly patterns, and future encrypted backup.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                MealMarkPlusStatusPill(
                    title: storeKit.isPlusActive ? "Plus active" : "Free active",
                    systemImage: storeKit.isPlusActive ? "checkmark.seal.fill" : "person.crop.circle",
                    tint: storeKit.isPlusActive ? .green : .secondary
                )
                .accessibilityIdentifier("MealMarkPlusStatusPill")
            }
            .padding(.vertical, 8)
        }
    }

    private var usageSection: some View {
        Section("Usage") {
            MealMarkPlusUsageRow(
                title: "Free",
                detail: "Manual logging, local history, scan proof, basic export, and basic photo drafts.",
                usage: usageLabel(limit: SubscriptionState.free.monthlyPhotoEstimateLimit),
                isCurrent: !storeKit.isPlusActive
            )
            MealMarkPlusUsageRow(
                title: "Plus",
                detail: "Higher photo-draft limit, advanced mixed-dish assumptions, weekly insights, and future encrypted backup.",
                usage: usageLabel(limit: SubscriptionState.plus.monthlyPhotoEstimateLimit),
                isCurrent: storeKit.isPlusActive
            )
        }
    }

    @ViewBuilder
    private var productsSection: some View {
        Section("Subscription options") {
            if storeKit.isLoadingProducts && storeKit.products.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading localized App Store options...")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("MealMarkPlusProductsLoading")
            } else if storeKit.products.isEmpty {
                MealMarkPlusUnavailableRow(
                    message: storeKit.unavailableMessage ?? "MealMark Plus subscription options are not available in this build."
                )
                .accessibilityIdentifier("MealMarkPlusUnavailable")
            } else {
                ForEach(storeKit.products, id: \.id) { product in
                    MealMarkPlusProductRow(
                        product: product,
                        isActive: storeKit.activeProductIDs.contains(product.id),
                        isPurchasing: storeKit.purchasingProductID == product.id,
                        canMakePayments: storeKit.canMakePayments
                    ) {
                        await storeKit.purchase(product, accountManager: accountManager)
                    }
                }
            }

            if let statusMessage = storeKit.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
                    .accessibilityIdentifier("MealMarkPlusStatusMessage")
            }

            if let errorMessage = storeKit.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)
                    .accessibilityIdentifier("MealMarkPlusErrorMessage")
            }
            if let accountError = accountManager.errorMessage {
                Label(accountError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)
                    .accessibilityIdentifier("MealMarkAccountErrorMessage")
            }
        }
    }

    private var controlsSection: some View {
        Section {
            Button {
                Task {
                    await storeKit.restorePurchases(accountManager: accountManager)
                }
            } label: {
                HStack {
                    Label("Restore purchases", systemImage: "arrow.clockwise.circle")
                    Spacer()
                    if storeKit.isRestoring {
                        ProgressView()
                    }
                }
            }
            .disabled(storeKit.isRestoring)
            .accessibilityIdentifier("MealMarkPlusRestoreButton")

            Button {
                Task {
                    await storeKit.manageSubscriptions()
                }
            } label: {
                HStack {
                    Label("Manage with Apple", systemImage: "person.crop.circle.badge.checkmark")
                    Spacer()
                    if storeKit.isOpeningManageSubscriptions {
                        ProgressView()
                    }
                }
            }
            .disabled(storeKit.isOpeningManageSubscriptions)
            .accessibilityIdentifier("MealMarkPlusManageButton")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountManager.accountState.status == .localOnly ? "Local mode" : "MealMark account")
                        .font(.headline)
                    Text(accountDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if accountManager.isRefreshing {
                    ProgressView()
                }
            }

            Button(role: .destructive) {
                Task {
                    await accountManager.deleteCloudAccount()
                    await storeKit.refresh(accountManager: accountManager)
                }
            } label: {
                Label("Delete cloud account", systemImage: "trash")
            }
            .disabled(accountManager.accountState.status == .localOnly || !accountManager.isConfigured)
            .accessibilityIdentifier("MealMarkDeleteCloudAccountButton")
        }
    }

    private var valueSection: some View {
        Section("What Plus adds") {
            MealMarkPlusFeatureRow(
                title: "Higher photo-draft limit",
                detail: "Use photo estimates more often without changing manual logging.",
                systemImage: "camera.badge.ellipsis"
            )
            MealMarkPlusFeatureRow(
                title: "Mixed-meal review",
                detail: "Keep assumptions visible when MealMark estimates complex meals.",
                systemImage: "slider.horizontal.3"
            )
            MealMarkPlusFeatureRow(
                title: "Weekly patterns",
                detail: "Turn confirmed records into private trends and recap views.",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            MealMarkPlusFeatureRow(
                title: "Encrypted backup path",
                detail: "Prepare for portable, user-controlled backup and sync.",
                systemImage: "lock.icloud"
            )
        }
    }

    private var termsSection: some View {
        Section {
            Text("Purchases are processed by Apple. Prices and renewal terms come from the App Store when products are available.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func usageLabel(limit: Int) -> String {
        let remaining = max(0, limit - min(subscription.usedPhotoEstimates, limit))
        return "\(remaining) of \(limit) photo drafts left this month"
    }

    private var accountDetail: String {
        guard accountManager.isConfigured else {
            return "Cloud account is not configured in this build."
        }
        if let accountID = accountManager.accountState.accountID {
            return "\(accountManager.accountState.entitlement.tier.label) • \(accountID)"
        }
        return "MealMark will create a private account before purchases or cloud quota sync."
    }
}

private struct MealMarkPlusStatusPill: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
    }
}

private struct MealMarkPlusUsageRow: View {
    var title: String
    var detail: String
    var usage: String
    var isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                if isCurrent {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(usage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MealMarkPlusUnavailableRow: View {
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Subscriptions unavailable", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Free MealMark remains available in local and development builds.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct MealMarkPlusProductRow: View {
    var product: Product
    var isActive: Bool
    var isPurchasing: Bool
    var canMakePayments: Bool
    var purchase: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(priceLabel)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 12)

                if isActive {
                    MealMarkPlusStatusPill(title: "Active", systemImage: "checkmark", tint: .green)
                } else {
                    Button {
                        Task {
                            await purchase()
                        }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text(canMakePayments ? "Choose" : "Disabled")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing || !canMakePayments)
                    .accessibilityIdentifier("MealMarkPlusChoose-\(product.id)")
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var priceLabel: String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayPrice
        }
        return "\(product.displayPrice) / \(period.localizedShortName)"
    }
}

private struct MealMarkPlusFeatureRow: View {
    var title: String
    var detail: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension Product.SubscriptionPeriod {
    var localizedShortName: String {
        let unitName: String
        switch unit {
        case .day:
            unitName = value == 1 ? "day" : "days"
        case .week:
            unitName = value == 1 ? "week" : "weeks"
        case .month:
            unitName = value == 1 ? "month" : "months"
        case .year:
            unitName = value == 1 ? "year" : "years"
        @unknown default:
            unitName = "period"
        }

        if value == 1 {
            return unitName
        }
        return "\(value) \(unitName)"
    }
}
