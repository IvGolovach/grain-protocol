import FoodWalletCore
import GrainFoodWallet
import SwiftUI

private enum FoodWalletTab: String, CaseIterable, Identifiable {
    case today
    case capture
    case history
    case wallet
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .capture: return "Capture"
        case .history: return "History"
        case .wallet: return "Wallet"
        case .pro: return "Pro"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "list.bullet.rectangle"
        case .capture: return "camera.viewfinder"
        case .history: return "calendar"
        case .wallet: return "checkmark.seal"
        case .pro: return "sparkles"
        }
    }
}

struct FoodWalletRootView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var selectedTab: FoodWalletTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(selectedTab: $selectedTab)
            }
            .tabItem { Label(FoodWalletTab.today.title, systemImage: FoodWalletTab.today.symbol) }
            .tag(FoodWalletTab.today)

            NavigationStack {
                CaptureView(selectedTab: $selectedTab)
            }
            .tabItem { Label(FoodWalletTab.capture.title, systemImage: FoodWalletTab.capture.symbol) }
            .tag(FoodWalletTab.capture)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label(FoodWalletTab.history.title, systemImage: FoodWalletTab.history.symbol) }
            .tag(FoodWalletTab.history)

            NavigationStack {
                WalletView()
            }
            .tabItem { Label(FoodWalletTab.wallet.title, systemImage: FoodWalletTab.wallet.symbol) }
            .tag(FoodWalletTab.wallet)

            NavigationStack {
                ProView()
            }
            .tabItem { Label(FoodWalletTab.pro.title, systemImage: FoodWalletTab.pro.symbol) }
            .tag(FoodWalletTab.pro)
        }
        .tint(.green)
        .accessibilityIdentifier("FoodWalletRoot")
    }
}

private struct TodayView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Binding var selectedTab: FoodWalletTab

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Food Wallet")
                        .font(.largeTitle.bold())
                    Text(store.todayTotalLabel)
                        .font(.title2.weight(.semibold))
                    Text("AI drafts become records only after you confirm them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Quick actions") {
                Button {
                    selectedTab = .capture
                } label: {
                    Label("Add food", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("AddFoodButton")
            }

            Section("Saved today") {
                if store.entries.isEmpty {
                    EmptyStateView(
                        title: "No meals yet",
                        symbol: "fork.knife",
                        message: "Capture a photo estimate or save a manual draft."
                    )
                } else {
                    ForEach(store.entries, id: \.entryID) { entry in
                        MealRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Today")
    }
}

private struct CaptureView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Binding var selectedTab: FoodWalletTab

    var body: some View {
        List {
            Section {
                Text("Photo creates a draft. You decide what gets saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Try photo analysis") {
                CaptureAction(
                    title: "Analyze Fuji apple",
                    subtitle: "Single-item estimate with a tight range",
                    symbol: "apple.logo"
                ) {
                    store.chooseExample(.fujiApple)
                    Task {
                        await store.analyzeSelectedExample()
                        selectedTab = .capture
                    }
                }

                CaptureAction(
                    title: "Analyze mushroom risotto",
                    subtitle: "Mixed dish with assumptions and a wider range",
                    symbol: "camera.macro"
                ) {
                    store.chooseExample(.mushroomRisotto)
                    Task {
                        await store.analyzeSelectedExample()
                        selectedTab = .capture
                    }
                }
            }

            Section("Review draft") {
                if store.hasDraft {
                    DraftReviewView()
                } else {
                    EmptyStateView(
                        title: "No active draft",
                        symbol: "doc.text.magnifyingglass",
                        message: "Analyze a sample photo to create a Food Wallet draft."
                    )
                }
            }
        }
        .navigationTitle("Capture")
    }
}

private struct DraftReviewView: View {
    @EnvironmentObject private var store: FoodWalletStore

    var body: some View {
        if let candidate = store.currentCandidate {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.primaryLabel)
                            .font(.title3.bold())
                        Text("\(candidate.portion.label) • \(candidate.nutrition.label)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SourceBadge(text: "Estimated", tint: .orange)
                }

                Label(candidate.confidence.label, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Assumptions")
                        .font(.headline)
                    ForEach(candidate.assumptions) { assumption in
                        Toggle(assumption.label, isOn: Binding(
                            get: { assumption.isEnabled },
                            set: { _ in store.toggleAssumption(id: assumption.id) }
                        ))
                        .accessibilityIdentifier("Assumption-\(assumption.id)")
                    }
                }

                HStack {
                    Button(role: .cancel) {
                        store.discardDraft()
                    } label: {
                        Label("Discard", systemImage: "xmark")
                    }

                    Spacer()

                    Button {
                        store.confirmDraft()
                    } label: {
                        Label("Save to Food Wallet", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .accessibilityIdentifier("SaveToFoodWalletButton")
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: FoodWalletStore

    var body: some View {
        List {
            Section("Confirmed records") {
                if store.entries.isEmpty {
                    EmptyStateView(
                        title: "History is empty",
                        symbol: "calendar",
                        message: "Confirmed Food Wallet records will appear here."
                    )
                } else {
                    ForEach(store.entries, id: \.entryID) { entry in
                        MealRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct WalletView: View {
    @EnvironmentObject private var store: FoodWalletStore

    var body: some View {
        List {
            Section("Status") {
                LabeledContent("Storage", value: "Local-first")
                LabeledContent("Confirmed entries", value: "\(store.entries.count)")
                LabeledContent("AI consent", value: store.privacy.label)
            }

            Section("Privacy promises") {
                ForEach(PrivacyPromise.defaultPromises, id: \.title) { promise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(promise.title)
                            .font(.headline)
                        Text(promise.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Developer proof") {
                Text("Safe summaries show food labels, calories, source class, and trust labels. They do not include raw photos or protocol/private material.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    store.resetLocalData()
                } label: {
                    Label("Reset local data", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Wallet")
    }
}

private struct ProView: View {
    @EnvironmentObject private var store: FoodWalletStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Food Wallet Pro")
                        .font(.largeTitle.bold())
                    Text("More photo estimates, advanced mixed-dish analysis, weekly insights, and future encrypted sync.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(store.subscription.summary)
                        .font(.headline)
                }
                .padding(.vertical, 8)
            }

            Section("Pro value") {
                Label("Higher photo-estimate limits", systemImage: "camera.badge.ellipsis")
                Label("Advanced mixed-dish assumptions", systemImage: "slider.horizontal.3")
                Label("Weekly nutrition patterns", systemImage: "chart.line.uptrend.xyaxis")
                Label("Future encrypted backup", systemImage: "lock.icloud")
            }

            Section {
                Button {
                    // StoreKit products are wired in a later App Store lane.
                } label: {
                    Label("Review subscription options", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Pro")
    }
}

private struct MealRow: View {
    var entry: FoodIntakeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.meal.label)
                    .font(.headline)
                Text("\(entry.meal.amountGrams) g • \(entry.meal.kcal) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SourceBadge(text: entry.trustStatus.label, tint: entry.trustStatus == .verified ? .green : .orange)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SourceBadge: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct CaptureAction: View {
    var title: String
    var subtitle: String
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateView: View {
    var title: String
    var symbol: String
    var message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }
}
