import FoodWalletCore
import GrainFoodWallet
import SwiftUI

#if os(iOS)
import UIKit
#endif

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
    @State private var isShowingCamera = false
    @State private var captureErrorMessage: String?

    private var usesUITestPhotoFlow: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--grain-ui-test-photo-flow") ||
            arguments.contains("--grain-ui-test-delayed-photo-flow") ||
            arguments.contains("--grain-ui-test-failing-photo-flow")
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(onAddFood: startAddFoodFlow)
            }
            .tabItem { Label(FoodWalletTab.today.title, systemImage: FoodWalletTab.today.symbol) }
            .tag(FoodWalletTab.today)

            NavigationStack {
                CaptureView(selectedTab: $selectedTab, onCapturePhoto: startAddFoodFlow)
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
        #if os(iOS)
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView(
                onPhotoCaptured: { photoPayload in
                    isShowingCamera = false
                    Task {
                        await store.analyze(photoPayload: photoPayload)
                    }
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
        }
        #endif
        .alert(
            "Camera unavailable",
            isPresented: Binding(
                get: { captureErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        captureErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(captureErrorMessage ?? "")
        }
    }

    private func startAddFoodFlow() {
        selectedTab = .capture

        if usesUITestPhotoFlow {
            Task {
                await store.analyze(photo: .uiTestFujiApple)
            }
            return
        }

        #if os(iOS)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingCamera = true
        } else {
            captureErrorMessage = "This device does not expose a camera to Food Wallet. Use a real iPhone for camera capture."
        }
        #else
        captureErrorMessage = "Camera capture is available in the iOS app target on a real iPhone."
        #endif
    }
}

private struct TodayView: View {
    @EnvironmentObject private var store: FoodWalletStore
    var onAddFood: () -> Void

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
                Button(action: onAddFood) {
                    Label("Add food", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("AddFoodButton")
            }

            Section("Saved today") {
                if store.todayEntries.isEmpty {
                    EmptyStateView(
                        title: "No meals yet",
                        symbol: "fork.knife",
                        message: "Capture a photo estimate or save a manual draft."
                    )
                } else {
                    ForEach(store.todayEntries, id: \.entryID) { entry in
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
    var onCapturePhoto: () -> Void

    var body: some View {
        List {
            Section {
                Text("Photo creates a draft. You decide what gets saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Camera") {
                CaptureAction(
                    title: "Take meal photo",
                    subtitle: "Open camera and create a nutrition draft",
                    symbol: "camera.fill",
                    accessibilityIdentifier: "TakeMealPhotoButton",
                    isDisabled: !store.canStartAnalysis,
                    action: onCapturePhoto
                )
            }

            Section("Try photo analysis") {
                CaptureAction(
                    title: "Analyze Fuji apple",
                    subtitle: "Single-item estimate with a tight range",
                    symbol: "apple.logo",
                    accessibilityIdentifier: "AnalyzeFujiAppleButton",
                    isDisabled: !store.canStartAnalysis
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
                    symbol: "camera.macro",
                    accessibilityIdentifier: "AnalyzeMushroomRisottoButton",
                    isDisabled: !store.canStartAnalysis
                ) {
                    store.chooseExample(.mushroomRisotto)
                    Task {
                        await store.analyzeSelectedExample()
                        selectedTab = .capture
                    }
                }
            }

            Section("Review draft") {
                if store.analysisState.isAnalyzing {
                    AnalysisProgressCard(state: store.analysisState) {
                        store.cancelAnalysis()
                    }
                } else if let errorMessage = store.analysisState.errorMessage {
                    AnalysisFailureCard(
                        message: errorMessage,
                        onRetry: onCapturePhoto,
                        onDismiss: store.discardDraft
                    )
                } else if store.analysisState == .blockedPrivacy {
                    AnalysisBlockedCard {
                        store.discardDraft()
                    }
                } else if store.hasDraft {
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

private struct AnalysisProgressCard: View {
    var state: FoodAnalysisState
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanForward = false
    @State private var stepIndex = 0
    @State private var hasTakenLonger = false

    private let steps = [
        "Looking for food",
        "Estimating portion",
        "Checking nutrition ranges",
        "Preparing draft"
    ]

    private var statusText: String {
        if state.isSlow || hasTakenLonger {
            return "Still working..."
        }
        return steps[stepIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                scanner

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.green)
                            .accessibilityIdentifier("AnalysisLoadingIndicator")
                        Text(statusText)
                            .font(.headline)
                            .accessibilityIdentifier("AnalysisStatusLabel")
                    }

                    Text("Food Wallet is turning this photo into a reviewable nutrition draft.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AnalysisStepList(steps: steps, activeIndex: stepIndex)

            if state.isSlow || hasTakenLonger {
                HStack {
                    Label("Still analyzing. You can cancel and try another photo.", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel, action: onCancel)
                        .accessibilityIdentifier("CancelAnalysisButton")
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.green.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("AnalysisLoadingView")
        .task(id: state) {
            stepIndex = 0
            hasTakenLonger = state.isSlow
            guard state.isAnalyzing else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_350_000_000)
                guard !Task.isCancelled else {
                    return
                }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    stepIndex = (stepIndex + 1) % steps.count
                }
            }
        }
        .task(id: state.isSlow) {
            if state.isSlow {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    hasTakenLonger = true
                }
            }
        }
    }

    private var scanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.green.opacity(0.11))
                .frame(width: 72, height: 72)

            Image(systemName: "viewfinder")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.green)

            if !reduceMotion {
                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, .green.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 56, height: 3)
                    .offset(y: scanForward ? 24 : -24)
                    .animation(
                        .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
                        value: scanForward
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            scanForward = true
        }
    }
}

private struct AnalysisStepList: View {
    var steps: [String]
    var activeIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: index <= activeIndex ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(index <= activeIndex ? .green : .secondary)
                    Text(steps[index])
                        .font(.caption)
                        .foregroundStyle(index == activeIndex ? .primary : .secondary)
                }
            }
        }
        .accessibilityIdentifier("AnalysisStepList")
    }
}

private struct AnalysisFailureCard: View {
    var message: String
    var onRetry: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Couldn’t analyze photo", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("AnalysisErrorMessage")
            HStack {
                Button("Dismiss", role: .cancel, action: onDismiss)
                    .accessibilityIdentifier("DismissAnalysisErrorButton")
                Spacer()
                Button(action: onRetry) {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityIdentifier("RetryAnalysisButton")
            }
        }
        .padding(.vertical, 8)
    }
}

private struct AnalysisBlockedCard: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI photo analysis disabled", systemImage: "lock.shield")
                .font(.headline)
            Text("Food Wallet did not send this photo for analysis because AI photo analysis is disabled.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Dismiss", role: .cancel, action: onDismiss)
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("AnalysisPrivacyBlockedView")
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
                            .accessibilityIdentifier("DraftPrimaryLabel")
                        Text("\(candidate.portion.label) • \(candidate.nutrition.label)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("DraftNutritionLabel")
                        Text(candidate.macronutrients.shortLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("DraftMacronutrientsLabel")
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
                    .disabled(!store.canSaveDraft)
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
                LabeledContent {
                    Text("\(store.entries.count)")
                        .accessibilityIdentifier("ConfirmedEntriesValue")
                } label: {
                    Text("Confirmed entries")
                        .accessibilityIdentifier("ConfirmedEntriesLabel")
                }
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
                    .accessibilityIdentifier("MealRowLabel-\(entry.meal.label)")
                Text("\(entry.meal.amountGrams) g • \(entry.meal.kcal) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("MealRowNutrition-\(entry.meal.label)")
                if let macronutrients = entry.meal.macronutrients {
                    Text(macronutrients.shortLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("MealRowMacros-\(entry.meal.label)")
                }
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
    var accessibilityIdentifier: String
    var isDisabled = false
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
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityIdentifier(accessibilityIdentifier)
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
