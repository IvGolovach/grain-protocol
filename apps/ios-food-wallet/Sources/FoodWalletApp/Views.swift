import FoodWalletCore
import Foundation
import GrainFoodWallet
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import CoreImage.CIFilterBuiltins
import PhotosUI
import UIKit
#endif

private enum FoodWalletTab: String, CaseIterable, Identifiable {
    case today
    case history
    case wallet
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .history: return "History"
        case .wallet: return "Wallet"
        case .pro: return "Pro"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "list.bullet.rectangle"
        case .history: return "calendar"
        case .wallet: return "checkmark.seal"
        case .pro: return "sparkles"
        }
    }
}

private enum FoodWalletHaptics {
    @MainActor
    static func selectionChanged() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

private enum MealMarkKeyboard {
    @MainActor
    static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private struct MealMarkKeyboardDoneButton: View {
    var accessibilityIdentifier: String
    var title: String = "Done"
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.body.weight(.semibold))
            .disabled(!isEnabled)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private enum MealMarkAmountUnit: String, CaseIterable, Identifiable {
    case grams
    case ounces
    case cups

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .grams: return "g"
        case .ounces: return "oz"
        case .cups: return "cups"
        }
    }

    var fieldLabel: String {
        switch self {
        case .grams: return "grams"
        case .ounces: return "ounces"
        case .cups: return "cups"
        }
    }

    var placeholder: String {
        switch self {
        case .grams: return "g"
        case .ounces: return "oz"
        case .cups: return "cup"
        }
    }

    func grams(from text: String) -> Int64? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else {
            return nil
        }
        let grams: Double
        switch self {
        case .grams:
            grams = value
        case .ounces:
            grams = value * 28.349523125
        case .cups:
            grams = value * 240
        }
        return max(1, Int64(grams.rounded()))
    }

    func displayText(fromGrams grams: Int64) -> String {
        let value: Double
        let fractionDigits: Int
        switch self {
        case .grams:
            return "\(grams)"
        case .ounces:
            value = Double(grams) / 28.349523125
            fractionDigits = 1
        case .cups:
            value = Double(grams) / 240
            fractionDigits = 2
        }
        return Self.compactDecimal(value, fractionDigits: fractionDigits)
    }

    private static func compactDecimal(_ value: Double, fractionDigits: Int) -> String {
        let format = "%.\(fractionDigits)f"
        var text = String(format: format, value)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}

struct FoodWalletRootView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var selectedTab: FoodWalletTab = .today
    @State private var isShowingCamera = false
    @State private var isShowingAddFoodHub = false
    @State private var isShowingCaptureReview = false
    @State private var addFoodHubDetent = PresentationDetent.medium
    @State private var captureErrorMessage: String?
    #if os(iOS)
    @State private var isShowingPhotoLibrary = false
    @State private var selectedMealPhotoItem: PhotosPickerItem?
    #endif

    private var usesUITestPhotoFlow: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--grain-ui-test-photo-flow") ||
            arguments.contains("--grain-ui-test-delayed-photo-flow") ||
            arguments.contains("--grain-ui-test-no-food-photo-flow") ||
            arguments.contains("--grain-ui-test-failing-photo-flow")
    }

    private var tabSelection: Binding<FoodWalletTab> {
        Binding {
            selectedTab
        } set: { newValue in
            guard newValue != selectedTab else {
                return
            }
            FoodWalletHaptics.selectionChanged()
            selectedTab = newValue
        }
    }

    var body: some View {
        ZStack {
            tabContent
                .accessibilityHidden(store.analysisState.isAnalyzing)

            if store.analysisState.isAnalyzing {
                AnalysisProgressOverlay(state: store.analysisState) {
                    store.cancelAnalysis()
                }
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.analysisState.isAnalyzing)
        .tint(.green)
        .sheet(isPresented: $isShowingAddFoodHub) {
            NavigationStack {
                AddFoodHubView(
                    onDraftReady: {
                        isShowingAddFoodHub = false
                        showCaptureReviewSoon()
                    },
                    onTakePhoto: {
                        isShowingAddFoodHub = false
                        #if os(iOS)
                        DispatchQueue.main.async {
                            startCameraCaptureFlow()
                        }
                        #else
                        captureErrorMessage = "Camera capture is available in the iOS app target."
                        #endif
                    },
                    onChoosePhoto: {
                        isShowingAddFoodHub = false
                        #if os(iOS)
                        DispatchQueue.main.async {
                            isShowingPhotoLibrary = true
                        }
                        #else
                        captureErrorMessage = "Photo library import is available in the iOS app target."
                        #endif
                    }
                )
            }
            .presentationDetents([.medium, .large], selection: $addFoodHubDetent)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCaptureReview) {
            NavigationStack {
                CaptureView(
                    onCapturePhoto: startPhotoCaptureFlow,
                    onEnterManually: openManualAddFoodHub,
                    onDraftSaved: {
                        isShowingCaptureReview = false
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close") {
                            isShowingCaptureReview = false
                        }
                        .accessibilityIdentifier("CloseCaptureReviewButton")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView(
                onPhotoCaptured: { photoPayload in
                    isShowingCamera = false
                    analyze(photoPayload: photoPayload)
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $selectedMealPhotoItem,
            matching: .images
        )
        .onChange(of: selectedMealPhotoItem) { item in
            loadSelectedMealPhoto(item)
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

    private var tabContent: some View {
        TabView(selection: tabSelection) {
            NavigationStack {
                TodayView(onAddFood: openAddFoodHub)
            }
            .tabItem { Label(FoodWalletTab.today.title, systemImage: FoodWalletTab.today.symbol) }
            .tag(FoodWalletTab.today)

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
    }

    private func openAddFoodHub() {
        selectedTab = .today
        addFoodHubDetent = .medium

        if usesUITestPhotoFlow {
            Task {
                await store.analyze(photo: .uiTestFujiApple)
                await MainActor.run {
                    isShowingCaptureReview = true
                }
            }
            return
        }

        isShowingAddFoodHub = true
    }

    private func openManualAddFoodHub() {
        isShowingCaptureReview = false
        addFoodHubDetent = .medium
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isShowingAddFoodHub = true
        }
    }

    private func startPhotoCaptureFlow() {
        isShowingCaptureReview = false
        #if os(iOS)
        startCameraCaptureFlow()
        #else
        captureErrorMessage = "Photo capture is available in the iOS app target."
        #endif
    }

    #if os(iOS)
    private func startCameraCaptureFlow() {
        isShowingCaptureReview = false
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingCamera = true
        } else {
            captureErrorMessage = "This device does not expose a camera to MealMark. Use a real iPhone for camera capture."
        }
    }

    private func loadSelectedMealPhoto(_ item: PhotosPickerItem?) {
        guard let item else {
            return
        }
        selectedMealPhotoItem = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let payload = TransientMealPhotoPayload.transientCapture(from: image) else {
                    await MainActor.run {
                        captureErrorMessage = "MealMark could not read this photo. Choose another image or take a new picture."
                    }
                    return
                }
                await MainActor.run {
                    analyze(photoPayload: payload)
                }
            } catch {
                await MainActor.run {
                    captureErrorMessage = "MealMark could not load this photo. Choose another image or take a new picture."
                }
            }
        }
    }
    #endif

    private func analyze(photoPayload: TransientMealPhotoPayload) {
        Task {
            await store.analyze(photoPayload: photoPayload)
            await MainActor.run {
                isShowingCaptureReview = true
            }
        }
    }

    private func showCaptureReviewSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isShowingCaptureReview = true
        }
    }
}

private struct TodayView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var editingEntry: EditableMealEntry?
    @State private var isRefreshing = false
    var onAddFood: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            List {
                Section {
                    TodaySummaryCard(summary: store.todayNutritionSummary)
                }

                Section {
                    TodayAddFoodButton(action: onAddFood)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
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
                            NavigationLink {
                                MealDetailView(entryID: entry.entryID)
                            } label: {
                                MealRow(entry: entry)
                            }
                            .mealEntrySwipeActions(
                                entry: entry,
                                onEdit: { editingEntry = EditableMealEntry(entry: entry) }
                            )
                        }
                    }
                }
            }
            .refreshable {
                await refreshLocalState()
            }
            .mealMarkInsetGroupedListStyle()

            if isRefreshing {
                RunningGrainRefreshView()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
        .navigationTitle("Today")
        .sheet(item: $editingEntry) { editableEntry in
            EditMealEntryView(entry: editableEntry.entry)
        }
    }

    private func refreshLocalState() async {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        await store.refreshLocalState()
        try? await Task.sleep(nanoseconds: 650_000_000)
        isRefreshing = false
    }
}

private struct TodaySummaryCard: View {
    var summary: FoodWalletDailyNutritionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.entryCount == 0 ? "Nothing logged yet" : "You logged")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(summary.kcalRangeLabel)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .accessibilityIdentifier("TodayCaloriesSummary")

            HStack(spacing: 8) {
                macroPill(title: "Protein", value: "\(FoodWalletDailyNutritionSummary.display(summary.proteinGrams)) g")
                macroPill(title: "Carbs", value: "\(FoodWalletDailyNutritionSummary.display(summary.carbohydrateGrams)) g")
                macroPill(title: "Fat", value: "\(FoodWalletDailyNutritionSummary.display(summary.fatGrams)) g")
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("TodayNutritionSummaryCard")
    }

    private func macroPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TodayAddFoodButton: View {
    var action: () -> Void

    var body: some View {
        MealMarkFilledActionButton(
            title: "Add food",
            subtitle: "Photo, barcode, or build a meal",
            symbol: "plus.circle.fill",
            tint: .blue,
            minHeight: 72,
            action: action
        )
        .accessibilityIdentifier("AddFoodButton")
        .accessibilityLabel("Add food")
    }
}

private struct MealMarkFilledActionButton: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var tint: Color
    var isEnabled = true
    var minHeight: CGFloat = 56
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .opacity(0.84)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }

                Spacer(minLength: 8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(.horizontal, 18)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(tint.opacity(isEnabled ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct CaptureView: View {
    @EnvironmentObject private var store: FoodWalletStore
    var onCapturePhoto: () -> Void
    var onEnterManually: () -> Void
    var onDraftSaved: () -> Void = {}

    var body: some View {
        List {
            Section {
                if case let .failed(failure) = store.analysisState {
                    if failure.code == .noFoodDetected {
                        AnalysisNoFoodCard(
                            message: failure.message,
                            onRetry: onCapturePhoto,
                            onEnterManually: onEnterManually,
                            onDismiss: store.discardDraft
                        )
                    } else {
                        AnalysisFailureCard(
                            message: failure.message,
                            onRetry: onCapturePhoto,
                            onDismiss: store.discardDraft
                        )
                    }
                } else if store.analysisState == .blockedPrivacy {
                    AnalysisBlockedCard {
                        store.discardDraft()
                    }
                } else if store.hasDraft {
                    DraftReviewView(onSaved: onDraftSaved)
                } else {
                    EmptyStateView(
                        title: "No active draft",
                        symbol: "doc.text.magnifyingglass",
                        message: "Use Add Food to create a reviewable MealMark draft."
                    )
                }
            }
        }
        .mealMarkScrollDismissesKeyboard()
        .navigationTitle("Review food")
        .mealMarkNavigationBarTitleDisplayModeInline()
    }
}

private struct IngredientBuilderRow: Identifiable {
    let id = UUID()
    var name = ""
    var grams = ""
    var unit: MealMarkAmountUnit = .grams

    var resolvedGrams: Int64? {
        unit.grams(from: grams)
    }

    mutating func setAmount(fromGrams grams: Int64) {
        self.grams = unit.displayText(fromGrams: grams)
    }

    mutating func convert(to newUnit: MealMarkAmountUnit) {
        guard newUnit != unit else {
            return
        }
        let currentGrams = resolvedGrams
        unit = newUnit
        if let currentGrams {
            grams = newUnit.displayText(fromGrams: currentGrams)
        }
    }
}

private struct AddFoodHubView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: AddFoodFocus?
    @State private var searchText = ""
    @State private var selectedScope: AddFoodScope = .all
    @State private var mealTitle = ""
    @State private var ingredientRows = [
        IngredientBuilderRow(),
        IngredientBuilderRow(),
    ]
    @State private var ingredientErrorMessage: String?
    @State private var personalIngredientName: String?
    @State private var personalServingGrams = ""
    @State private var personalServingKcal = ""
    @State private var personalProteinGrams = ""
    @State private var personalCarbohydrateGrams = ""
    @State private var personalFatGrams = ""
    @State private var personalFiberGrams = ""
    @State private var personalIngredientErrorMessage: String?
    @State private var isShowingBarcodeLookup = false
    @State private var isShowingBuildMeal = false
    @State private var selectedSavedRecipeID: String?
    @State private var selectedPersonalIngredientID: String?
    @State private var unresolvedFoodName: String?
    @State private var isShowingManualNutrition = false

    var onDraftReady: () -> Void
    var onTakePhoto: () -> Void
    var onChoosePhoto: () -> Void

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchQuery: Bool {
        !trimmedSearchText.isEmpty
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    AddFoodSearchField(
                        text: $searchText,
                        focusedField: $focusedField,
                        onSubmit: createTypedFoodDraft
                    )

                    if shouldShowShortcuts {
                        AddFoodShortcutGrid(
                            canStartPhoto: store.canStartAnalysis,
                            onCamera: onTakePhoto,
                            onLibrary: onChoosePhoto,
                            onBarcode: {
                                isShowingBarcodeLookup = true
                            },
                            onBuild: {
                                isShowingBuildMeal = true
                            }
                        )
                    } else {
                        Text("Results update below as you type.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("AddFoodSearchModeHint")
                    }
                }
                .padding(.vertical, 4)
            }

            if shouldShowLibraryResults {
                Section("My meals") {
                    ForEach(Array(store.savedRecipes.prefix(6)), id: \.id) { recipe in
                        AddFoodResultRow(
                            title: recipe.title,
                            subtitle: "\(recipe.subtitle) • \(recipe.totalGrams) g • \(recipe.totalKcal) kcal",
                            symbol: "book.closed",
                            accessibilityIdentifier: "SavedRecipe-\(recipe.id)"
                        ) {
                            selectedSavedRecipeID = recipe.id
                        }
                    }

                    ForEach(Array(store.personalIngredients.prefix(4)), id: \.id) { ingredient in
                        AddFoodResultRow(
                            title: ingredient.name,
                            subtitle: "\(Int64(ingredient.sourceServingGrams.rounded())) g serving • \(ingredient.sourceServingKcal) kcal",
                            symbol: "person.crop.circle.badge.checkmark",
                            accessibilityIdentifier: "SavedPersonalFood-\(ingredient.id)"
                        ) {
                            selectedPersonalIngredientID = ingredient.id
                        }
                    }
                }
            }

            if shouldShowReusableResults {
                Section("Recent") {
                    ForEach(Array(reusableRecentEntries.prefix(3)), id: \.entryID) { entry in
                        AddFoodResultRow(
                            title: entry.meal.label,
                            subtitle: "\(entry.meal.amountGrams) g • \(entry.meal.kcal) kcal • \(entry.dateKey)",
                            symbol: "clock.arrow.circlepath",
                            accessibilityIdentifier: "RecentMeal-\(entry.entryID)"
                        ) {
                            createRecentDraft(entryID: entry.entryID)
                        }
                    }

                    ForEach(Array(reusablePersonalIngredients.prefix(2)), id: \.id) { ingredient in
                        AddFoodResultRow(
                            title: ingredient.name,
                            subtitle: "\(Int64(ingredient.sourceServingGrams.rounded())) g serving • \(ingredient.sourceServingKcal) kcal",
                            symbol: "person.crop.circle.badge.checkmark",
                            accessibilityIdentifier: "PersonalFood-\(ingredient.id)"
                        ) {
                            createPersonalFoodDraft(ingredient)
                        }
                    }
                }
            }

            if hasSearchQuery {
                Section(resultsSectionTitle) {
                    AddFoodScopeBar(selectedScope: $selectedScope)

                    if shouldShowFoodSearchResults {
                        ForEach(Array(filteredFoodSearchRows.prefix(12).enumerated()), id: \.element.id) { index, row in
                            AddFoodResultRow(
                                title: row.title,
                                subtitle: "\(row.subtitle ?? row.sourceLabel) • \(row.sourceLabel)",
                                symbol: "checkmark.seal",
                                accessibilityIdentifier: foodSearchAccessibilityIdentifier(for: row, index: index)
                            ) {
                                createFoodSearchDraft(id: row.id)
                            }
                        }
                    }

                    if shouldShowRecentResults {
                        ForEach(Array(filteredRecentEntries.prefix(4)), id: \.entryID) { entry in
                            AddFoodResultRow(
                                title: entry.meal.label,
                                subtitle: "\(entry.meal.amountGrams) g • \(entry.meal.kcal) kcal • \(entry.dateKey)",
                                symbol: "clock.arrow.circlepath",
                                accessibilityIdentifier: "RecentMeal-\(entry.entryID)"
                            ) {
                                createRecentDraft(entryID: entry.entryID)
                            }
                        }
                    }

                    if shouldShowTemplateResults {
                        ForEach(Array(filteredTemplates.prefix(4)), id: \.id) { template in
                            AddFoodResultRow(
                                title: template.title,
                                subtitle: "\(template.subtitle) • \(template.amountGrams) g • \(template.kcal) kcal",
                                symbol: "fork.knife.circle",
                                accessibilityIdentifier: "Template-\(template.id)"
                            ) {
                                createTemplateDraft(id: template.id)
                            }
                        }
                    }

                    if shouldShowRecipeResults {
                        ForEach(Array(filteredRecipes.prefix(4)), id: \.id) { recipe in
                            AddFoodResultRow(
                                title: recipe.title,
                                subtitle: "\(recipe.subtitle) • \(recipe.totalGrams) g • \(recipe.totalKcal) kcal",
                                symbol: "book.closed",
                                accessibilityIdentifier: "Recipe-\(recipe.id)"
                            ) {
                                createRecipeDraft(id: recipe.id)
                            }
                        }
                    }

                    if shouldShowPersonalFoodResults {
                        ForEach(Array(filteredPersonalIngredients.prefix(4)), id: \.id) { ingredient in
                            AddFoodResultRow(
                                title: ingredient.name,
                                subtitle: "\(Int64(ingredient.sourceServingGrams.rounded())) g serving • \(ingredient.sourceServingKcal) kcal",
                                symbol: "person.crop.circle.badge.checkmark",
                                accessibilityIdentifier: "PersonalFood-\(ingredient.id)"
                            ) {
                                createPersonalFoodDraft(ingredient)
                            }
                        }
                    }

                    if shouldShowEmptyResults {
                        EmptyStateView(
                            title: emptyResultsTitle,
                            symbol: selectedScope.emptySymbol,
                            message: emptyResultsMessage
                        )
                    }

                    if shouldShowUnknownFoodResolution {
                        UnknownFoodResolutionView(
                            foodName: unresolvedFoodName ?? trimmedSearchText,
                            searchState: store.foodSearchState,
                            isManualEntryVisible: isShowingManualNutrition,
                            onSearchAgain: searchProviderDatabasesForUnresolvedFood,
                            onEnterManually: enterNutritionForUnresolvedFood,
                            onScanCode: {
                                isShowingBarcodeLookup = true
                            },
                            onPhotoLabel: onTakePhoto
                        )
                    }
                }
            }
        }
        .mealMarkScrollDismissesKeyboard()
        .navigationTitle("Add Food")
        .mealMarkNavigationBarTitleDisplayModeInline()
        .onChange(of: trimmedSearchText) { _ in
            resetUnresolvedFood()
        }
        .task(id: trimmedSearchText) {
            await refreshBrokerFoodSearchForCurrentQuery()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                MealMarkKeyboardDoneButton(accessibilityIdentifier: "AddFoodKeyboardDoneButton") {
                    focusedField = nil
                    MealMarkKeyboard.dismiss()
                }
            }
        }
        .navigationDestination(isPresented: $isShowingBuildMeal) {
            BuildMealEditorView(
                mealTitle: $mealTitle,
                ingredientRows: $ingredientRows,
                ingredientErrorMessage: ingredientErrorMessage,
                personalIngredientName: personalIngredientName,
                personalServingGrams: $personalServingGrams,
                personalServingKcal: $personalServingKcal,
                personalProteinGrams: $personalProteinGrams,
                personalCarbohydrateGrams: $personalCarbohydrateGrams,
                personalFatGrams: $personalFatGrams,
                personalFiberGrams: $personalFiberGrams,
                personalIngredientErrorMessage: personalIngredientErrorMessage,
                canCreateIngredientDraft: canCreateIngredientDraft,
                onAddIngredient: {
                    ingredientRows.append(IngredientBuilderRow())
                },
                onCreateDraft: createIngredientMealDraft,
                onSavePersonalIngredient: savePersonalIngredient
            )
        }
        .navigationDestination(isPresented: $isShowingManualNutrition) {
            if let personalIngredientName {
                StandalonePersonalIngredientEntryView(
                    ingredientName: personalIngredientName,
                    servingGrams: $personalServingGrams,
                    servingKcal: $personalServingKcal,
                    proteinGrams: $personalProteinGrams,
                    carbohydrateGrams: $personalCarbohydrateGrams,
                    fatGrams: $personalFatGrams,
                    fiberGrams: $personalFiberGrams,
                    errorMessage: personalIngredientErrorMessage,
                    onSave: saveStandalonePersonalIngredient
                )
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: isShowingSavedRecipeDetail) {
            if let selectedSavedRecipeID {
                SavedMealDetailView(recipeID: selectedSavedRecipeID, onDraftReady: onDraftReady)
            }
        }
        .navigationDestination(isPresented: isShowingPersonalIngredientDetail) {
            if let selectedPersonalIngredientID {
                PersonalFoodDetailView(ingredientID: selectedPersonalIngredientID, onDraftReady: onDraftReady)
            }
        }
        .sheet(isPresented: $isShowingBarcodeLookup) {
            NavigationStack {
                BarcodeLookupView(onDraftReady: onDraftReady)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isShowingSavedRecipeDetail: Binding<Bool> {
        Binding(
            get: { selectedSavedRecipeID != nil },
            set: { isShowing in
                if !isShowing {
                    selectedSavedRecipeID = nil
                }
            }
        )
    }

    private var isShowingPersonalIngredientDetail: Binding<Bool> {
        Binding(
            get: { selectedPersonalIngredientID != nil },
            set: { isShowing in
                if !isShowing {
                    selectedPersonalIngredientID = nil
                }
            }
        )
    }

    private static func slug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    @MainActor
    private func refreshBrokerFoodSearchForCurrentQuery() async {
        guard hasSearchQuery, trimmedSearchText.count >= 2 else {
            store.clearBrokerFoodSearch()
            return
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else {
            return
        }
        await store.searchBrokerFood(query: trimmedSearchText)
    }

    private var canCreateIngredientDraft: Bool {
        !mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            ingredientRows.contains { row in
                !row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    (row.resolvedGrams ?? 0) > 0
            }
    }

    private var filteredRecentEntries: [FoodIntakeEntry] {
        store.entries.filter { matches($0.meal.label, secondary: $0.dateKey) }
    }

    private var filteredTemplates: [SavedFoodTemplate] {
        store.savedTemplates.filter { matches($0.title, secondary: $0.subtitle) }
    }

    private var filteredRecipes: [SavedFoodRecipe] {
        store.savedRecipes.filter { matches($0.title, secondary: $0.subtitle) }
    }

    private var filteredPersonalIngredients: [PersonalFoodIngredient] {
        store.personalIngredients.filter { matches($0.name, secondary: "\($0.sourceServingKcal) kcal") }
    }

    private var reusableRecentEntries: [FoodIntakeEntry] {
        hasSearchQuery ? [] : store.entries
    }

    private var reusablePersonalIngredients: [PersonalFoodIngredient] {
        []
    }

    private var shouldShowLibraryResults: Bool {
        !hasSearchQuery && (!store.savedRecipes.isEmpty || !store.personalIngredients.isEmpty)
    }

    private var shouldShowShortcuts: Bool {
        !hasSearchQuery && focusedField != .search
    }

    private var shouldShowReusableResults: Bool {
        !hasSearchQuery && (!reusableRecentEntries.isEmpty || !reusablePersonalIngredients.isEmpty)
    }

    private var filteredFoodSearchRows: [AddFoodSuggestionRow] {
        guard hasSearchQuery, selectedScope == .all || selectedScope == .myFoods else {
            return []
        }
        return store.addFoodSearchSuggestions(for: trimmedSearchText)
    }

    private var shouldShowFoodSearchResults: Bool {
        !filteredFoodSearchRows.isEmpty
    }

    private var shouldShowRecentResults: Bool {
        (selectedScope == .all || selectedScope == .recent) && !filteredRecentEntries.isEmpty
    }

    private var shouldShowTemplateResults: Bool {
        (selectedScope == .all || selectedScope == .myMeals) && !filteredTemplates.isEmpty
    }

    private var shouldShowRecipeResults: Bool {
        (selectedScope == .all || selectedScope == .myRecipes) && !filteredRecipes.isEmpty
    }

    private var shouldShowPersonalFoodResults: Bool {
        (selectedScope == .all || selectedScope == .myFoods) && !filteredPersonalIngredients.isEmpty
    }

    private var shouldShowEmptyResults: Bool {
        !shouldShowUnknownFoodResolution &&
            !shouldShowFoodSearchResults &&
            !shouldShowRecentResults &&
            !shouldShowTemplateResults &&
            !shouldShowRecipeResults &&
            !shouldShowPersonalFoodResults
    }

    private var shouldShowUnknownFoodResolution: Bool {
        hasSearchQuery &&
            selectedScope == .all &&
            !shouldShowFoodSearchResults &&
            !shouldShowRecentResults &&
            !shouldShowTemplateResults &&
            !shouldShowRecipeResults &&
            !shouldShowPersonalFoodResults
    }

    private var resultsSectionTitle: String {
        "Results"
    }

    private var emptyResultsTitle: String {
        if hasSearchQuery {
            return "No matches"
        }
        return selectedScope.emptyTitle
    }

    private var emptyResultsMessage: String {
        if hasSearchQuery {
            return "Try another word, search provider databases, or enter nutrition from a label."
        }
        return selectedScope.emptyMessage
    }

    private func matches(_ primary: String, secondary: String? = nil) -> Bool {
        guard hasSearchQuery else {
            return false
        }
        return primary.localizedCaseInsensitiveContains(trimmedSearchText) ||
            (secondary?.localizedCaseInsensitiveContains(trimmedSearchText) ?? false)
    }

    private func createTypedFoodDraft() {
        createTypedFoodDraft(trimmedSearchText)
    }

    private func createTypedFoodDraft(_ text: String) {
        guard store.createTypedFoodDraft(text) else {
            prepareUnresolvedFood(text)
            return
        }
        onDraftReady()
    }

    private func prepareUnresolvedFood(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        unresolvedFoodName = trimmed
        isShowingManualNutrition = false
        personalIngredientErrorMessage = nil
    }

    private func resetUnresolvedFood() {
        unresolvedFoodName = nil
        isShowingManualNutrition = false
        personalIngredientErrorMessage = nil
        if !isShowingBuildMeal {
            personalIngredientName = nil
        }
    }

    private func searchProviderDatabasesForUnresolvedFood() {
        let query = (unresolvedFoodName ?? trimmedSearchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        unresolvedFoodName = query
        Task {
            await store.searchBrokerFood(query: query)
        }
    }

    private func enterNutritionForUnresolvedFood() {
        let name = (unresolvedFoodName ?? trimmedSearchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        focusedField = nil
        MealMarkKeyboard.dismiss()
        unresolvedFoodName = name
        preparePersonalIngredientForm(for: name)
        isShowingManualNutrition = true
    }

    private func createFoodSearchDraft(id: String) {
        if store.createFoodSearchSuggestionDraft(id: id) {
            onDraftReady()
        }
    }

    private func createRecentDraft(entryID: String) {
        if store.createRecentEntryDraft(entryID: entryID) {
            onDraftReady()
        }
    }

    private func createTemplateDraft(id: String) {
        if store.createTemplateDraft(id: id) {
            onDraftReady()
        }
    }

    private func createRecipeDraft(id: String) {
        if store.createRecipeDraft(id: id, consumedFraction: 1) {
            onDraftReady()
        }
    }

    private func createPersonalFoodDraft(_ ingredient: PersonalFoodIngredient) {
        let servingGrams = max(1, Int64(ingredient.sourceServingGrams.rounded()))
        let result = store.createIngredientMealDraft(
            title: ingredient.name,
            ingredients: [
                FoodMealIngredientInput(name: ingredient.name, grams: servingGrams),
            ]
        )
        if result == .created {
            onDraftReady()
        }
    }

    private func createIngredientMealDraft() {
        let inputs = ingredientRows.map { row in
            FoodMealIngredientInput(
                name: row.name,
                grams: row.resolvedGrams ?? 0
            )
        }
        let result = store.createIngredientMealDraft(title: mealTitle, ingredients: inputs)
        switch result {
        case .created:
            ingredientErrorMessage = nil
            personalIngredientErrorMessage = nil
            onDraftReady()
        case .emptyTitle:
            ingredientErrorMessage = "Add a meal name."
        case .noIngredients:
            ingredientErrorMessage = "Add at least one ingredient."
        case let .invalidGrams(name):
            ingredientErrorMessage = "Check amount for \(name)."
        case let .unknownIngredient(name):
            ingredientErrorMessage = "Choose a verified result for \(name), or add the label nutrition manually."
            preparePersonalIngredientForm(for: name)
        }
    }

    private func preparePersonalIngredientForm(for name: String) {
        if personalIngredientName != name {
            personalIngredientName = name
            personalServingGrams = ""
            personalServingKcal = ""
            personalProteinGrams = ""
            personalCarbohydrateGrams = ""
            personalFatGrams = ""
            personalFiberGrams = ""
            personalIngredientErrorMessage = nil
        }
    }

    private func savePersonalIngredient() {
        guard let personalIngredientName else {
            return
        }
        let result = store.savePersonalIngredient(
            name: personalIngredientName,
            servingGrams: decimalValue(personalServingGrams),
            servingKcal: Int64(decimalValue(personalServingKcal).rounded()),
            proteinGrams: decimalValue(personalProteinGrams),
            carbohydrateGrams: decimalValue(personalCarbohydrateGrams),
            fatGrams: decimalValue(personalFatGrams),
            fiberGrams: personalFiberGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : decimalValue(personalFiberGrams)
        )
        switch result {
        case .saved:
            self.personalIngredientName = nil
            personalIngredientErrorMessage = nil
            createIngredientMealDraft()
        case .emptyName:
            personalIngredientErrorMessage = "Add an ingredient name."
        case .invalidServingGrams:
            personalIngredientErrorMessage = "Enter serving grams from the label."
        case .invalidCalories:
            personalIngredientErrorMessage = "Enter calories from the label."
        case let .invalidMacro(name):
            personalIngredientErrorMessage = "Check \(name) grams."
        }
    }

    private func saveStandalonePersonalIngredient() {
        guard let personalIngredientName else {
            return
        }
        let servingGrams = decimalValue(personalServingGrams)
        let result = store.savePersonalIngredient(
            name: personalIngredientName,
            servingGrams: servingGrams,
            servingKcal: Int64(decimalValue(personalServingKcal).rounded()),
            proteinGrams: decimalValue(personalProteinGrams),
            carbohydrateGrams: decimalValue(personalCarbohydrateGrams),
            fatGrams: decimalValue(personalFatGrams),
            fiberGrams: personalFiberGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : decimalValue(personalFiberGrams)
        )
        switch result {
        case .saved:
            let savedName = personalIngredientName
            let loggedGrams = max(1, Int64(servingGrams.rounded()))
            self.personalIngredientName = nil
            unresolvedFoodName = nil
            isShowingManualNutrition = false
            personalIngredientErrorMessage = nil
            let creationResult = store.createIngredientMealDraft(
                title: savedName,
                ingredients: [
                    FoodMealIngredientInput(name: savedName, grams: loggedGrams),
                ]
            )
            if creationResult == .created {
                onDraftReady()
            } else {
                personalIngredientErrorMessage = "Saved, but could not create a review draft yet."
            }
        case .emptyName:
            personalIngredientErrorMessage = "Add an ingredient name."
        case .invalidServingGrams:
            personalIngredientErrorMessage = "Enter serving grams from the label."
        case .invalidCalories:
            personalIngredientErrorMessage = "Enter calories from the label."
        case let .invalidMacro(name):
            personalIngredientErrorMessage = "Check \(name) grams."
        }
    }

    private func decimalValue(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func foodSearchAccessibilityIdentifier(for row: AddFoodSuggestionRow, index: Int) -> String {
        if index == 0, hasSearchQuery {
            return "FoodSearchResult-\(Self.slug(trimmedSearchText))"
        }
        return "FoodSearchResult-\(Self.slug(row.title))"
    }
}

private struct BuildMealEditorView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @FocusState private var focusedIngredientNameIndex: Int?
    @Binding var mealTitle: String
    @Binding var ingredientRows: [IngredientBuilderRow]
    var ingredientErrorMessage: String?
    var personalIngredientName: String?
    @Binding var personalServingGrams: String
    @Binding var personalServingKcal: String
    @Binding var personalProteinGrams: String
    @Binding var personalCarbohydrateGrams: String
    @Binding var personalFatGrams: String
    @Binding var personalFiberGrams: String
    var personalIngredientErrorMessage: String?
    var canCreateIngredientDraft: Bool
    var onAddIngredient: () -> Void
    var onCreateDraft: () -> Void
    var onSavePersonalIngredient: () -> Void

    var body: some View {
        List {
            if let personalIngredientName {
                Section {
                    PersonalIngredientResolutionView(
                        ingredientName: personalIngredientName,
                        servingGrams: $personalServingGrams,
                        servingKcal: $personalServingKcal,
                        proteinGrams: $personalProteinGrams,
                        carbohydrateGrams: $personalCarbohydrateGrams,
                        fatGrams: $personalFatGrams,
                        fiberGrams: $personalFiberGrams,
                        errorMessage: personalIngredientErrorMessage,
                        onSave: onSavePersonalIngredient
                    )
                }
            }

            Section {
                TextField("Meal name", text: $mealTitle)
                    .accessibilityIdentifier("MealTitleField")

                ForEach(ingredientRows.indices, id: \.self) { index in
                    IngredientBuilderRowView(
                        index: index,
                        row: $ingredientRows[index],
                        suggestions: store.ingredientSuggestions(for: ingredientRows[index].name, limit: 12),
                        focusedIngredientNameIndex: $focusedIngredientNameIndex,
                        onSelectSuggestion: { suggestion in
                            selectIngredientSuggestion(suggestion, at: index)
                        }
                    )
                }

                Button(action: onAddIngredient) {
                    Label("Add ingredient", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("AddIngredientRowButton")

                if let ingredientErrorMessage {
                    Text(ingredientErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("IngredientBuilderError")
                }
            } header: {
                Text("Ingredients")
            }

            Section {
                MealMarkFilledActionButton(
                    title: "Create meal draft",
                    subtitle: "Review before saving",
                    symbol: "fork.knife.circle.fill",
                    tint: .green,
                    isEnabled: canCreateIngredientDraft,
                    action: onCreateDraft
                )
                .accessibilityIdentifier("CreateIngredientMealDraftButton")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
        .mealMarkScrollDismissesKeyboard()
        .navigationTitle("Build Meal")
        .accessibilityIdentifier("BuildMealScreen")
        .task(id: ingredientSearchSeed) {
            await refreshBrokerFoodSearchForActiveIngredient()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                MealMarkKeyboardDoneButton(accessibilityIdentifier: "BuildMealKeyboardDoneButton") {
                    MealMarkKeyboard.dismiss()
                }
            }
        }
    }

    private func selectIngredientSuggestion(_ suggestion: AddFoodSuggestionRow, at index: Int) {
        if suggestion.id.hasPrefix("food-search:"),
           let ingredient = store.saveBrokerFoodSearchResultAsPersonalIngredient(id: suggestion.id) {
            ingredientRows[index].name = ingredient.name
            if ingredientRows[index].grams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ingredientRows[index].setAmount(fromGrams: max(1, Int64(ingredient.sourceServingGrams.rounded())))
            }
            return
        }

        ingredientRows[index].name = suggestion.title
        if ingredientRows[index].grams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let gramsMode = suggestion.portion?.gramsMode {
            ingredientRows[index].setAmount(fromGrams: gramsMode)
        }
    }

    private var ingredientSearchSeed: String {
        "\(focusedIngredientNameIndex.map(String.init) ?? "none")|\(activeIngredientQuery ?? "")"
    }

    @MainActor
    private func refreshBrokerFoodSearchForActiveIngredient() async {
        guard let query = activeIngredientQuery else {
            return
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else {
            return
        }
        await store.searchBrokerFood(query: query)
    }

    private var activeIngredientQuery: String? {
        guard let index = focusedIngredientNameIndex,
              ingredientRows.indices.contains(index) else {
            return nil
        }
        let query = ingredientRows[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.count >= 2 ? query : nil
    }
}

private struct BarcodeLookupView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isBarcodeFieldFocused: Bool
    @State private var barcodeText = ""
    @State private var errorMessage: String?
    @State private var isLookingUp = false
    @State private var detectedBarcode: String?
    @State private var detectedQRCodeText: String?
    @State private var qrPreview: FoodWalletQRImportPreview?
    @State private var scannerRestartID = UUID()

    var onDraftReady: () -> Void

    private var normalizedBarcode: String? {
        BrokerFoodSearchRequest.normalizeBarcode(barcodeText)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    BarcodeScannerView(
                        onBarcode: { barcode in
                            handleDetectedBarcode(barcode)
                        },
                        onQRCode: { payloadText in
                            handleDetectedQRCode(payloadText)
                        },
                        onScannerError: { message in
                            errorMessage = message
                        }
                    )
                    .id(scannerRestartID)
                    .frame(minHeight: 260)

                    if let qrPreview {
                        QRCodeImportPreviewCard(preview: qrPreview) {
                            createQRCodeDraft()
                        }
                    } else if let detectedBarcode {
                        Label("Detected \(detectedBarcode)", systemImage: "barcode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("BarcodeDetectedValueLabel")

                        barcodeManualControls
                    } else {
                        barcodeManualControls
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Packaged foods use broker-side databases. MealMark food QR works offline and still opens review before saving.")
            }
        }

        .mealMarkScrollDismissesKeyboard()
        .navigationTitle("Scan code")
        .mealMarkNavigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("BarcodeScannerSheet")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("BarcodeCancelButton")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                MealMarkKeyboardDoneButton(
                    accessibilityIdentifier: "BarcodeKeyboardSearchButton",
                    title: normalizedBarcode == nil ? "Done" : "Search",
                    isEnabled: !isLookingUp
                ) {
                    MealMarkKeyboard.dismiss()
                    isBarcodeFieldFocused = false
                    if normalizedBarcode != nil {
                        lookupManualBarcode()
                    }
                }
            }
        }
    }

    private var barcodeManualControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Enter UPC or EAN", text: $barcodeText)
                .textContentType(.oneTimeCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .focused($isBarcodeFieldFocused)
                .accessibilityIdentifier("BarcodeManualEntryField")

            MealMarkFilledActionButton(
                title: isLookingUp ? "Looking up" : "Look up barcode",
                subtitle: isLookingUp ? "Checking product databases" : nil,
                symbol: isLookingUp ? "hourglass" : "arrow.right.circle.fill",
                tint: .green,
                isEnabled: normalizedBarcode != nil && !isLookingUp,
                action: lookupManualBarcode
            )
            .accessibilityIdentifier("BarcodeManualLookupButton")

            statusLabel
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isLookingUp {
            Text("Checking food databases")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("BarcodeLookupStatusLabel")
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("BarcodeLookupErrorLabel")

                Button {
                    scanAgain()
                } label: {
                    Label("Scan again", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("BarcodeScanAgainButton")
            }
        } else {
            Text("Use the camera or type the digits printed under the barcode.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("BarcodeLookupStatusLabel")
        }
    }

    private func handleDetectedBarcode(_ value: String) {
        guard let normalized = BrokerFoodSearchRequest.normalizeBarcode(value) else {
            errorMessage = "Center the UPC or EAN digits and try again."
            return
        }
        detectedBarcode = normalized
        barcodeText = normalized
        Task {
            await lookupBarcode(normalized)
        }
    }

    private func handleDetectedQRCode(_ text: String) {
        do {
            qrPreview = try store.previewQRCodePayload(text)
            detectedQRCodeText = text
            errorMessage = nil
        } catch FoodWalletQRImportError.protocolServingOfferRequiresTrust {
            errorMessage = "This is a Grain GR1 serving offer. MealMark can read that protocol family, but adding it needs issuer trust material."
        } catch {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("GR1:") {
                errorMessage = "This is a Grain GR1 serving offer, but MealMark could not import the embedded food record yet."
            } else {
                errorMessage = "This QR is not a valid signed MealMark food QR. Try scanning again or enter the food manually."
            }
        }
    }

    private func scanAgain() {
        errorMessage = nil
        detectedBarcode = nil
        detectedQRCodeText = nil
        qrPreview = nil
        scannerRestartID = UUID()
    }

    private func createQRCodeDraft() {
        guard let detectedQRCodeText else {
            errorMessage = "Scan a MealMark food QR first."
            return
        }
        do {
            try store.createQRCodeDraft(payloadText: detectedQRCodeText)
            onDraftReady()
        } catch {
            errorMessage = "MealMark could not import this QR. Ask the sender to share it again."
        }
    }

    private func lookupManualBarcode() {
        guard let normalizedBarcode else {
            errorMessage = "Enter 8 to 14 barcode digits."
            return
        }
        Task {
            await lookupBarcode(normalizedBarcode)
        }
    }

    @MainActor
    private func lookupBarcode(_ barcode: String) async {
        guard !isLookingUp else {
            return
        }
        isLookingUp = true
        errorMessage = nil
        await store.searchBrokerFood(barcode: barcode)
        defer {
            isLookingUp = false
        }

        switch store.foodSearchState {
        case .ready:
            guard let firstResult = store.brokerFoodSearchRows.first,
                  store.createBrokerFoodSearchDraft(id: firstResult.id) else {
                errorMessage = "No reviewable barcode match yet. Try photo or enter the food manually."
                return
            }
        case .empty:
            errorMessage = "No product match for this barcode yet. Try photo or enter the food manually."
            return
        case let .failed(message):
            errorMessage = message
            return
        case .idle, .loading:
            errorMessage = "Food lookup did not finish. Try again."
            return
        }
        onDraftReady()
    }
}

private struct QRCodeImportPreviewCard: View {
    var preview: FoodWalletQRImportPreview
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("MealMark signed food QR", systemImage: "qrcode.viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .accessibilityIdentifier("QRCodeImportStatusLabel")

            VStack(alignment: .leading, spacing: 5) {
                Text(preview.title)
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("QRCodeImportPreviewTitle")
                Text(preview.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(preview.macronutrientsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Label(preview.signedByLabel, systemImage: "signature")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("QRCodeImportSignedBy")

            if !preview.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ingredients")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(preview.ingredients.prefix(5).enumerated()), id: \.offset) { _, ingredient in
                        Text(ingredient)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            MealMarkFilledActionButton(
                title: "Add to today",
                subtitle: "Open review first",
                symbol: "checkmark.circle.fill",
                tint: .green,
                action: onAdd
            )
            .accessibilityIdentifier("QRCodeImportAddButton")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("QRCodeImportPreviewCard")
    }
}

private enum AddFoodFocus: Hashable {
    case search
}

private enum AddFoodScope: String, CaseIterable, Identifiable {
    case all
    case recent
    case myMeals
    case myRecipes
    case myFoods

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .myMeals: return "My Meals"
        case .myRecipes: return "My Recipes"
        case .myFoods: return "My Foods"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "Nothing saved yet"
        case .recent: return "No recent meals"
        case .myMeals: return "No saved meals"
        case .myRecipes: return "No recipes"
        case .myFoods: return "No personal foods"
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: return "magnifyingglass"
        case .recent: return "clock"
        case .myMeals: return "fork.knife"
        case .myRecipes: return "book.closed"
        case .myFoods: return "person.crop.circle"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all:
            return "Type a food, take a photo, or build a meal from ingredients."
        case .recent:
            return "Confirmed meals will appear here for one-tap repeats."
        case .myMeals:
            return "Saved meal templates will appear here when they are available."
        case .myRecipes:
            return "Saved recipes will appear here when they are available."
        case .myFoods:
            return "Custom ingredients you save from labels will appear here."
        }
    }
}

private struct AddFoodSearchField: View {
    @Binding var text: String
    var focusedField: FocusState<AddFoodFocus?>.Binding
    var onSubmit: () -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search or describe food", text: $text)
                .focused(focusedField, equals: .search)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("FoodSearchField")
                .accessibilityIdentifier("AddFoodSearchField")

            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
            }
            .disabled(trimmedText.isEmpty)
            .accessibilityLabel("Search food")
            .accessibilityIdentifier("CreateTypedFoodDraftButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .mealMarkGlassSurface(cornerRadius: 16, isInteractive: true)
    }
}

private struct AddFoodShortcutGrid: View {
    var canStartPhoto: Bool
    var onCamera: () -> Void
    var onLibrary: () -> Void
    var onBarcode: () -> Void
    var onBuild: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            shortcutContainer {
                LazyVGrid(columns: columns, spacing: 10) {
                    AddFoodShortcutButton(
                        title: "Camera",
                        subtitle: canStartPhoto ? "Take photo" : "Unavailable",
                        symbol: "camera.fill",
                        accessibilityIdentifier: "AddFoodPhotoCameraButton",
                        isEnabled: canStartPhoto,
                        tint: .green,
                        action: onCamera
                    )

                    AddFoodShortcutButton(
                        title: "Library",
                        subtitle: "Choose photo",
                        symbol: "photo.on.rectangle",
                        accessibilityIdentifier: "AddFoodPhotoLibraryButton",
                        isEnabled: canStartPhoto,
                        tint: .teal,
                        action: onLibrary
                    )

                    AddFoodShortcutButton(
                        title: "Barcode",
                        subtitle: "UPC or QR",
                        symbol: "barcode.viewfinder",
                        accessibilityIdentifier: "AddFoodModeBarcodeButton",
                        tint: .blue,
                        action: onBarcode
                    )

                    AddFoodShortcutButton(
                        title: "Build",
                        subtitle: "Ingredients",
                        symbol: "list.bullet.clipboard",
                        accessibilityIdentifier: "AddFoodModeBuildMealButton",
                        tint: .purple,
                        action: onBuild
                    )
                }
            }

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityLabel("Add food modes")
                .accessibilityIdentifier("AddFoodModeChooser")
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func shortcutContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                content()
            }
        } else {
            content()
        }
    }
}

private struct AddFoodShortcutButton: View {
    var title: String
    var subtitle: String
    var symbol: String
    var accessibilityIdentifier: String
    var isEnabled = true
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AddFoodShortcutTile(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                isEnabled: isEnabled,
                tint: tint
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.7)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(subtitle)
    }
}

private struct AddFoodShortcutTile: View {
    var title: String
    var subtitle: String
    var symbol: String
    var isEnabled: Bool
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            shortcutIcon
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            titleStack(titleFont: .subheadline.weight(.semibold), subtitleFont: .caption2.weight(.medium))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .padding(12)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .mealMarkGlassSurface(
            cornerRadius: 16,
            tint: isEnabled ? tint.opacity(0.09) : Color.secondary.opacity(0.08),
            isInteractive: isEnabled
        )
    }

    private var shortcutIcon: some View {
        Image(systemName: symbol)
    }

    private func titleStack(titleFont: Font, subtitleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(titleFont)
                .lineLimit(1)

            Text(subtitle)
                .font(subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private extension View {
    @ViewBuilder
    func mealMarkNavigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func mealMarkScrollDismissesKeyboard() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    @ViewBuilder
    func mealMarkInsetGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }

    @ViewBuilder
    func mealMarkGlassSurface(
        cornerRadius: CGFloat,
        tint: Color = Color.secondary.opacity(0.08),
        isInteractive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                isInteractive
                    ? .regular.tint(tint).interactive()
                    : .regular.tint(tint),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                }
        }
    }
}

private struct AddFoodScopeBar: View {
    @Binding var selectedScope: AddFoodScope

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AddFoodScope.allCases) { scope in
                    Button {
                        selectedScope = scope
                    } label: {
                        Text(scope.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minHeight: 34)
                            .background(
                                scope == selectedScope
                                    ? Color.green.opacity(0.16)
                                    : Color.secondary.opacity(0.08)
                            )
                            .foregroundStyle(scope == selectedScope ? Color.green : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("AddFoodScope-\(scope.rawValue)")
                }
            }
        }
    }
}

private struct AddFoodResultRow: View {
    var title: String
    var subtitle: String
    var symbol: String
    var accessibilityIdentifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(width: 28, height: 28)
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct UnknownFoodResolutionView: View {
    var foodName: String
    var searchState: FoodSearchState
    var isManualEntryVisible: Bool
    var onSearchAgain: () -> Void
    var onEnterManually: () -> Void
    var onScanCode: () -> Void
    var onPhotoLabel: () -> Void

    private var isSearching: Bool {
        searchState == .loading
    }

    private var statusText: String {
        switch searchState {
        case .loading:
            return "Searching provider databases..."
        case .empty:
            return "No verified nutrition match yet."
        case let .failed(message):
            return message
        case .idle, .ready:
            return "MealMark will not guess calories for unknown food."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Find a source for \(foodName)")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("UnknownFoodResolutionTitle")
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                resolutionButton(
                    title: isSearching ? "Searching..." : "Search provider databases",
                    symbol: isSearching ? "hourglass" : "magnifyingglass.circle.fill",
                    tint: .blue,
                    isEnabled: !isSearching,
                    accessibilityIdentifier: "SearchDeeperFoodButton",
                    action: onSearchAgain
                )

                HStack(spacing: 10) {
                    resolutionButton(
                        title: isManualEntryVisible ? "Manual entry open" : "Enter label",
                        symbol: "square.and.pencil",
                        tint: .green,
                        isEnabled: !isManualEntryVisible,
                        accessibilityIdentifier: "EnterManualNutritionButton",
                        action: onEnterManually
                    )
                    resolutionButton(
                        title: "Scan code",
                        symbol: "barcode.viewfinder",
                        tint: .purple,
                        accessibilityIdentifier: "UnknownFoodBarcodeButton",
                        action: onScanCode
                    )
                }

                resolutionButton(
                    title: "Photo label",
                    symbol: "camera.viewfinder",
                    tint: .orange,
                    accessibilityIdentifier: "UnknownFoodPhotoLabelButton",
                    action: onPhotoLabel
                )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("UnknownFoodResolutionCard")
    }

    private func resolutionButton(
        title: String,
        symbol: String,
        tint: Color,
        isEnabled: Bool = true,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 12)
            .background(tint.opacity(isEnabled ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct IngredientBuilderRowView: View {
    var index: Int
    @Binding var row: IngredientBuilderRow
    var suggestions: [AddFoodSuggestionRow] = []
    var focusedIngredientNameIndex: FocusState<Int?>.Binding
    var onSelectSuggestion: (AddFoodSuggestionRow) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Ingredient", text: $row.name)
                    .focused(focusedIngredientNameIndex, equals: index)
                    .accessibilityIdentifier("IngredientNameField-\(index)")

                HStack(spacing: 6) {
                    TextField(row.unit.placeholder, text: $row.grams)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .accessibilityIdentifier("IngredientGramsField-\(index)")

                    Menu {
                        ForEach(MealMarkAmountUnit.allCases) { unit in
                            Button {
                                row.convert(to: unit)
                            } label: {
                                if unit == row.unit {
                                    Label(unit.shortLabel, systemImage: "checkmark")
                                } else {
                                    Text(unit.shortLabel)
                                }
                            }
                        }
                    } label: {
                        Text(row.unit.shortLabel)
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 42, minHeight: 34)
                            .foregroundStyle(.blue)
                            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityLabel("Ingredient unit")
                    .accessibilityIdentifier("IngredientUnitButton-\(index)")
                }
            }

            if shouldShowSuggestions {
                VStack(spacing: 6) {
                    ForEach(Array(suggestions.prefix(8).enumerated()), id: \.element.id) { suggestionIndex, suggestion in
                        Button {
                            onSelectSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestionIcon(for: suggestion))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(suggestion.subtitle ?? suggestion.sourceLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Text(suggestion.sourceLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(suggestionIndex == 0 ? 0.13 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("IngredientSuggestion-\(index)-\(Self.slug(suggestion.title))")
                    }
                }
            }
        }
    }

    private var shouldShowSuggestions: Bool {
        let trimmed = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return false
        }
        return focusedIngredientNameIndex.wrappedValue == index && !suggestions.isEmpty
    }

    private static func slug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func suggestionIcon(for suggestion: AddFoodSuggestionRow) -> String {
        switch suggestion.kind {
        case .personalIngredient:
            return "person.crop.circle.badge.checkmark"
        case .providerMatch:
            return "checkmark.seal"
        default:
            return "magnifyingglass"
        }
    }
}

private struct SavedRecipeLibraryRow: View {
    var recipe: SavedFoodRecipe

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(recipe.totalGrams) g • \(recipe.totalKcal) kcal • \(recipe.subtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PersonalFoodLibraryRow: View {
    var ingredient: PersonalFoodIngredient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.headline)
                .foregroundStyle(.purple)
                .frame(width: 30, height: 30)
                .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(ingredient.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(Int64(ingredient.sourceServingGrams.rounded())) g • \(ingredient.sourceServingKcal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct SavedMealDetailView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    var recipeID: String
    var onDraftReady: () -> Void

    private var recipe: SavedFoodRecipe? {
        store.savedRecipe(id: recipeID)
    }

    var body: some View {
        Group {
            if let recipe {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.title)
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("SavedMealDetailTitle")
                            Text("\(recipe.totalGrams) g • \(recipe.totalKcal) kcal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(recipe.macronutrients.shortLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }

                    Section("Ingredients") {
                        ForEach(recipe.ingredients) { ingredient in
                            SavedMealIngredientRow(ingredient: ingredient)
                        }
                    }

                    Section {
                        Button {
                            if store.createRecipeDraft(id: recipe.id, consumedFraction: 1) {
                                onDraftReady()
                                dismiss()
                            }
                        } label: {
                            Label("Log meal", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .accessibilityIdentifier("LogSavedMealButton")
                    }

                    QRCodePayloadCard(
                        title: recipe.title,
                        payloadText: store.qrPayloadTextForRecipe(id: recipe.id)
                    )

                    Section {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit recipe", systemImage: "pencil")
                        }
                        .accessibilityIdentifier("EditSavedMealButton")

                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete recipe", systemImage: "trash")
                        }
                        .accessibilityIdentifier("DeleteSavedMealButton")
                    }
                }
                .navigationTitle("Saved Meal")
                .mealMarkNavigationBarTitleDisplayModeInline()
                .sheet(isPresented: $isEditing) {
                    SavedRecipeEditorView(recipe: recipe)
                }
                .alert(
                    "Delete recipe?",
                    isPresented: $isConfirmingDelete
                ) {
                    Button("Delete recipe", role: .destructive) {
                        _ = store.deleteSavedRecipe(id: recipe.id)
                        dismiss()
                    }
                    Button("Keep recipe", role: .cancel) {}
                } message: {
                    Text(deleteRecipeMessage(recipe))
                }
            } else {
                EmptyStateView(
                    title: "Saved meal not found",
                    symbol: "exclamationmark.magnifyingglass",
                    message: "This meal is no longer in your library."
                )
            }
        }
    }

    private func deleteRecipeMessage(_ recipe: SavedFoodRecipe) -> String {
        "This removes \(recipe.title) from saved meals. Logged history stays unchanged."
    }
}

private struct SavedMealIngredientRow: View {
    var ingredient: SavedFoodRecipeIngredient

    var body: some View {
        LabeledContent(ingredient.label, value: nutritionText)
    }

    private var nutritionText: String {
        "\(ingredient.grams) g • \(ingredient.kcal) kcal"
    }
}

private struct PersonalFoodDetailView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    var ingredientID: String
    var onDraftReady: () -> Void

    private var ingredient: PersonalFoodIngredient? {
        store.personalIngredient(id: ingredientID)
    }

    var body: some View {
        Group {
            if let ingredient {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ingredient.name)
                                .font(.title2.bold())
                                .accessibilityIdentifier("PersonalFoodDetailTitle")
                            Text("\(Int64(ingredient.sourceServingGrams.rounded())) g • \(ingredient.sourceServingKcal) kcal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(ingredient.macronutrientsPer100Grams.shortLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }

                    Section {
                        Button {
                            let servingGrams = max(1, Int64(ingredient.sourceServingGrams.rounded()))
                            let result = store.createIngredientMealDraft(
                                title: ingredient.name,
                                ingredients: [
                                    FoodMealIngredientInput(name: ingredient.name, grams: servingGrams),
                                ]
                            )
                            if result == .created {
                                onDraftReady()
                                dismiss()
                            }
                        } label: {
                            Label("Log food", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .accessibilityIdentifier("LogPersonalFoodButton")
                    }

                    QRCodePayloadCard(
                        title: ingredient.name,
                        payloadText: store.qrPayloadTextForPersonalIngredient(id: ingredient.id)
                    )
                }
                .navigationTitle("Personal Food")
                .mealMarkNavigationBarTitleDisplayModeInline()
            } else {
                EmptyStateView(
                    title: "Food not found",
                    symbol: "exclamationmark.magnifyingglass",
                    message: "This personal food is no longer available."
                )
            }
        }
    }
}

private struct SavedRecipeEditorView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedIngredientNameIndex: Int?
    @State private var mealTitle: String
    @State private var ingredientRows: [IngredientBuilderRow]
    @State private var errorMessage: String?
    private let recipeID: String

    init(recipe: SavedFoodRecipe) {
        recipeID = recipe.id
        _mealTitle = State(initialValue: recipe.title)
        _ingredientRows = State(initialValue: recipe.ingredients.map {
            IngredientBuilderRow(name: $0.label, grams: "\($0.grams)")
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Ingredients") {
                    TextField("Meal name", text: $mealTitle)
                        .accessibilityIdentifier("SavedRecipeTitleField")

                    ForEach(ingredientRows.indices, id: \.self) { index in
                        IngredientBuilderRowView(
                            index: index,
                            row: $ingredientRows[index],
                            suggestions: store.ingredientSuggestions(for: ingredientRows[index].name, limit: 12),
                            focusedIngredientNameIndex: $focusedIngredientNameIndex,
                            onSelectSuggestion: { suggestion in
                                if suggestion.id.hasPrefix("food-search:"),
                                   let ingredient = store.saveBrokerFoodSearchResultAsPersonalIngredient(id: suggestion.id) {
                                    ingredientRows[index].name = ingredient.name
                                    if ingredientRows[index].grams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        ingredientRows[index].setAmount(fromGrams: max(1, Int64(ingredient.sourceServingGrams.rounded())))
                                    }
                                    return
                                }
                                ingredientRows[index].name = suggestion.title
                                if ingredientRows[index].grams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   let gramsMode = suggestion.portion?.gramsMode {
                                    ingredientRows[index].setAmount(fromGrams: gramsMode)
                                }
                            }
                        )
                    }

                    Button {
                        ingredientRows.append(IngredientBuilderRow())
                    } label: {
                        Label("Add ingredient", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("SavedRecipeAddIngredientButton")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("SavedRecipeEditError")
                    }
                }
            }
            .mealMarkScrollDismissesKeyboard()
            .navigationTitle("Edit recipe")
            .task(id: ingredientSearchSeed) {
                await refreshBrokerFoodSearchForActiveIngredient()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CancelSavedRecipeEditButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("SaveSavedRecipeEditButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    MealMarkKeyboardDoneButton(accessibilityIdentifier: "SavedRecipeKeyboardDoneButton") {
                        MealMarkKeyboard.dismiss()
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            ingredientRows.contains { row in
                !row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    (row.resolvedGrams ?? 0) > 0
            }
    }

    private func save() {
        let inputs = ingredientRows.map { row in
            FoodMealIngredientInput(
                name: row.name,
                grams: row.resolvedGrams ?? 0
            )
        }
        let result = store.updateSavedRecipe(id: recipeID, title: mealTitle, ingredients: inputs)
        switch result {
        case .created:
            dismiss()
        case .emptyTitle:
            errorMessage = "Add a meal name."
        case .noIngredients:
            errorMessage = "Add at least one ingredient."
        case let .invalidGrams(name):
            errorMessage = "Check grams for \(name)."
        case let .unknownIngredient(name):
            errorMessage = "Add nutrition for \(name) before saving this recipe."
        }
    }

    private var ingredientSearchSeed: String {
        "\(focusedIngredientNameIndex.map(String.init) ?? "none")|\(activeIngredientQuery ?? "")"
    }

    @MainActor
    private func refreshBrokerFoodSearchForActiveIngredient() async {
        guard let query = activeIngredientQuery else {
            return
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else {
            return
        }
        await store.searchBrokerFood(query: query)
    }

    private var activeIngredientQuery: String? {
        guard let index = focusedIngredientNameIndex,
              ingredientRows.indices.contains(index) else {
            return nil
        }
        let query = ingredientRows[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.count >= 2 ? query : nil
    }
}

private struct QRCodePayloadCard: View {
    var title: String
    var payloadText: String?

    var body: some View {
        Section("Signed Grain QR") {
            if let payloadText {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share this food as a signed GR1 serving offer. It opens offline and still requires review before saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    #if os(iOS)
                    QRCodeImageView(payloadText: payloadText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("SavedMealQRCode")

                    if let imageURL = QRCodeRenderer.pngFileURL(payload: payloadText, title: title) {
                        ShareLink(item: imageURL) {
                            Label("Share QR image", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .accessibilityIdentifier("ShareQRCodeImageButton")
                    }
                    #endif

                    ShareLink(item: payloadText) {
                        Label("Share QR data", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ShareQRCodeDataButton")
                }
                .padding(.vertical, 4)
            } else {
                Text("QR is unavailable for this item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if os(iOS)
private struct QRCodeImageView: View {
    var payloadText: String

    var body: some View {
        if let image = QRCodeRenderer.image(payload: payloadText) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12))
                }
        } else {
            EmptyStateView(
                title: "QR unavailable",
                symbol: "qrcode",
                message: "MealMark could not render this code."
            )
        }
    }
}

private enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return nil
        }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    static func pngFileURL(payload: String, title: String) -> URL? {
        guard let data = image(payload: payload)?.pngData() else {
            return nil
        }
        let filename = "mealmark-\(slug(title)).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private static func slug(_ value: String) -> String {
        let slug = value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "food" : slug
    }
}
#endif

private struct PersonalIngredientResolutionView: View {
    let ingredientName: String
    @Binding var servingGrams: String
    @Binding var servingKcal: String
    @Binding var proteinGrams: String
    @Binding var carbohydrateGrams: String
    @Binding var fatGrams: String
    @Binding var fiberGrams: String
    var errorMessage: String?
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add custom ingredient")
                .font(.headline)

            Text("Use the nutrition label once. MealMark will reuse it next time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(ingredientName)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("PersonalIngredientNameLabel")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                PersonalIngredientInputField(
                    title: "Serving",
                    placeholder: "serving g",
                    text: $servingGrams,
                    keyboard: .decimal,
                    accessibilityID: "PersonalIngredientServingGramsField"
                )
                PersonalIngredientInputField(
                    title: "Calories",
                    placeholder: "kcal",
                    text: $servingKcal,
                    keyboard: .number,
                    accessibilityID: "PersonalIngredientCaloriesField"
                )
                PersonalIngredientInputField(
                    title: "Protein",
                    placeholder: "protein",
                    text: $proteinGrams,
                    keyboard: .decimal,
                    accessibilityID: "PersonalIngredientProteinField"
                )
                PersonalIngredientInputField(
                    title: "Carbs",
                    placeholder: "carbs",
                    text: $carbohydrateGrams,
                    keyboard: .decimal,
                    accessibilityID: "PersonalIngredientCarbsField"
                )
                PersonalIngredientInputField(
                    title: "Fat",
                    placeholder: "fat",
                    text: $fatGrams,
                    keyboard: .decimal,
                    accessibilityID: "PersonalIngredientFatField"
                )
                PersonalIngredientInputField(
                    title: "Fiber",
                    placeholder: "fiber",
                    text: $fiberGrams,
                    keyboard: .decimal,
                    accessibilityID: "PersonalIngredientFiberField"
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("PersonalIngredientError")
            }

            Button(action: onSave) {
                Label("Save custom ingredient", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("SavePersonalIngredientButton")
        }
        .padding(.vertical, 6)
    }
}

private struct StandalonePersonalIngredientEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let ingredientName: String
    @Binding var servingGrams: String
    @Binding var servingKcal: String
    @Binding var proteinGrams: String
    @Binding var carbohydrateGrams: String
    @Binding var fatGrams: String
    @Binding var fiberGrams: String
    var errorMessage: String?
    var onSave: () -> Void

    var body: some View {
        List {
            Section {
                PersonalIngredientResolutionView(
                    ingredientName: ingredientName,
                    servingGrams: $servingGrams,
                    servingKcal: $servingKcal,
                    proteinGrams: $proteinGrams,
                    carbohydrateGrams: $carbohydrateGrams,
                    fatGrams: $fatGrams,
                    fiberGrams: $fiberGrams,
                    errorMessage: errorMessage,
                    onSave: onSave
                )
            }
        }
        .mealMarkInsetGroupedListStyle()
        .mealMarkScrollDismissesKeyboard()
        .navigationTitle("Enter Nutrition")
        .mealMarkNavigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("UnknownFoodManualNutritionForm")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                MealMarkKeyboardDoneButton(accessibilityIdentifier: "UnknownFoodKeyboardDoneButton") {
                    MealMarkKeyboard.dismiss()
                }
            }
        }
    }
}

private struct PersonalIngredientInputField: View {
    enum Keyboard {
        case decimal
        case number
    }

    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: Keyboard
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .font(.body.monospacedDigit())
                .textFieldStyle(.plain)
                #if os(iOS)
                .keyboardType(keyboard == .number ? .numberPad : .decimalPad)
                #endif
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier(accessibilityID)
        }
    }
}

private struct AnalysisProgressOverlay: View {
    var state: FoodAnalysisState
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
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
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("Analysis in progress")
                .accessibilityIdentifier("AnalysisLoadingView")

            VStack(spacing: 28) {
                Spacer(minLength: 32)

                scanner

                VStack(spacing: 10) {
                    Text("Analyzing photo")
                        .font(.title2.weight(.semibold))

                    HStack(spacing: 9) {
                        ProgressView()
                            .tint(.green)
                            .accessibilityIdentifier("AnalysisLoadingIndicator")
                        Text(statusText)
                            .font(.headline.weight(.medium))
                            .accessibilityIdentifier("AnalysisStatusLabel")
                    }

                    Text("MealMark is turning this photo into a reviewable nutrition draft.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 320)

                AnalysisStepList(steps: steps, activeIndex: stepIndex)
                    .frame(maxWidth: 260)

                Spacer(minLength: 32)

                if state.isSlow || hasTakenLonger {
                    VStack(spacing: 12) {
                        Label("Still analyzing", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Cancel", role: .cancel, action: onCancel)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("CancelAnalysisButton")
                    }
                    .transition(.opacity)
                } else {
                    Color.clear
                        .frame(height: 52)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(.sRGB, red: 0.055, green: 0.07, blue: 0.06, opacity: 1)
        }
        return Color(.sRGB, red: 0.98, green: 0.985, blue: 0.975, opacity: 1)
    }

    private var scanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.green.opacity(0.11))
                .frame(width: 168, height: 168)

            Image(systemName: "viewfinder")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(.green)

            if !reduceMotion {
                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, .green.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 124, height: 4)
                    .offset(y: scanForward ? 56 : -56)
                    .animation(
                        .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
                        value: scanForward
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
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

private struct AnalysisNoFoodCard: View {
    var message: String
    var onRetry: () -> Void
    var onEnterManually: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "viewfinder.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 46, height: 46)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("No food recognized")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("NoFoodTitle")

                    Text(message.isEmpty ? "MealMark did not find visible food or a readable nutrition label in this photo." : message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("NoFoodMessage")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Nothing was saved.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button(action: onRetry) {
                    Label("Retake photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityIdentifier("RetryNoFoodPhotoButton")

                Button(action: onEnterManually) {
                    Label("Enter manually", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .accessibilityIdentifier("EnterFoodManuallyButton")

                Button(role: .cancel, action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("DismissNoFoodButton")
            }
        }
        .padding(18)
        .mealMarkGlassSurface(cornerRadius: 28, tint: Color.secondary.opacity(0.035), isInteractive: false)
    }
}

private struct AnalysisBlockedCard: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI photo analysis disabled", systemImage: "lock.shield")
                .font(.headline)
            Text("MealMark did not send this photo for analysis because AI photo analysis is disabled.")
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
    @State private var portionGramsText = ""
    @State private var portionUnit: MealMarkAmountUnit = .grams
    var onSaved: () -> Void = {}

    var body: some View {
        if let storedCandidate = store.currentCandidate {
            let candidate = previewCandidate(for: storedCandidate)
            let trustStatus = store.currentDraft?.trustStatus ?? .estimated
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        draftTitle(candidate: candidate)
                            .layoutPriority(1)
                        SourceBadge(
                            text: candidate.reviewBadgeText(trustStatus: trustStatus),
                            tint: trustStatus.reviewTint
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SourceBadge(
                            text: candidate.reviewBadgeText(trustStatus: trustStatus),
                            tint: trustStatus.reviewTint
                        )
                        draftTitle(candidate: candidate)
                    }
                }

                NutritionOverviewView(candidate: candidate, tint: trustStatus.reviewTint)

                PortionControlsView(
                    candidate: candidate,
                    gramsText: $portionGramsText,
                    unit: $portionUnit,
                    onCommit: commitPortion
                )

                DraftActionBar(
                    canSave: store.canSaveDraft,
                    onDiscard: store.discardDraft,
                    onSave: {
                        commitPortion()
                        store.confirmDraft()
                        onSaved()
                    }
                )
            }
            .padding(18)
            .mealMarkGlassSurface(cornerRadius: 30, tint: Color.secondary.opacity(0.035), isInteractive: false)
            .onAppear {
                resetPortionText(with: storedCandidate)
            }
            .onChange(of: storedCandidate.id) { _ in
                resetPortionText(with: storedCandidate)
            }
            .onChange(of: storedCandidate.portion.gramsMode) { gramsMode in
                portionGramsText = portionUnit.displayText(fromGrams: gramsMode)
            }
        }
    }

    private func commitPortion() {
        guard let candidate = store.currentCandidate else {
            return
        }
        guard let grams = portionUnit.grams(from: portionGramsText), grams > 0 else {
            portionGramsText = portionUnit.displayText(fromGrams: candidate.portion.gramsMode)
            return
        }
        if grams != candidate.portion.gramsMode {
            _ = store.updateCurrentDraftPortion(gramsMode: grams)
        }
        portionGramsText = portionUnit.displayText(fromGrams: grams)
    }

    private func previewCandidate(for candidate: FoodAnalysisCandidate) -> FoodAnalysisCandidate {
        guard let grams = portionUnit.grams(from: portionGramsText), grams > 0, grams != candidate.portion.gramsMode else {
            return candidate
        }
        return candidate.scaled(toGrams: grams)
    }

    private func resetPortionText(with candidate: FoodAnalysisCandidate) {
        portionGramsText = portionUnit.displayText(fromGrams: candidate.portion.gramsMode)
    }

    private func draftTitle(candidate: FoodAnalysisCandidate) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(candidate.primaryLabel)
                .font(.title2.weight(.bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
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
    }

}

private struct NutritionOverviewView: View {
    var candidate: FoodAnalysisCandidate
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(candidate.nutrition.modeKcal)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Label(candidate.confidence.label, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(tint.opacity(0.11), in: Capsule())
            }

            HStack(spacing: 8) {
                NutritionMetricView(title: "Protein", value: macroValue(candidate.macronutrients.proteinGrams), unit: "g")
                NutritionMetricView(title: "Carbs", value: macroValue(candidate.macronutrients.carbohydrateGrams), unit: "g")
                NutritionMetricView(title: "Fat", value: macroValue(candidate.macronutrients.fatGrams), unit: "g")
            }
        }
        .padding(14)
        .mealMarkGlassSurface(cornerRadius: 22, tint: Color.secondary.opacity(0.055), isInteractive: false)
    }

    private func macroValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return "\(rounded)"
    }
}

private struct NutritionMetricView: View {
    var title: String
    var value: String
    var unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(unit) \(title)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct DraftActionBar: View {
    var canSave: Bool
    var onDiscard: () -> Void
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(role: .destructive, action: onDiscard) {
                Label("Discard", systemImage: "trash")
                    .frame(minWidth: 112, minHeight: 50)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("DiscardDraftButton")

            Button(action: onSave) {
                Label("Add to today", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .background(Color.green.opacity(canSave ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("SaveToFoodWalletButton")
        }
    }
}

private struct PortionControlsView: View {
    @FocusState private var isGramsFieldFocused: Bool
    var candidate: FoodAnalysisCandidate
    @Binding var gramsText: String
    @Binding var unit: MealMarkAmountUnit
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Portion")
                    .font(.headline)
                Spacer()
                Text("\(unit.fieldLabel) eaten")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Picker("Portion unit", selection: $unit) {
                ForEach(MealMarkAmountUnit.allCases) { unit in
                    Text(unit.shortLabel).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("PortionUnitPicker")

            HStack(alignment: .center, spacing: 12) {
                portionButton(
                    symbol: "minus",
                    label: "Decrease portion",
                    identifier: "PortionDecreaseButton"
                ) {
                    update(to: max(1, candidate.portion.gramsMode - 25))
                }

                gramsField

                portionButton(
                    symbol: "plus",
                    label: "Increase portion",
                    identifier: "PortionIncreaseButton"
                ) {
                    update(to: candidate.portion.gramsMode + 25)
                }
            }
        }
        .padding(13)
        .mealMarkGlassSurface(cornerRadius: 22, tint: Color.secondary.opacity(0.045), isInteractive: false)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                MealMarkKeyboardDoneButton(accessibilityIdentifier: "PortionKeyboardDoneButton") {
                    commitAndDismiss()
                }
            }
        }
        .onChange(of: isGramsFieldFocused) { isFocused in
            if isFocused && gramsText == unit.displayText(fromGrams: candidate.portion.gramsMode) {
                gramsText = ""
            } else if !isFocused {
                onCommit()
            }
        }
        .onChange(of: unit) { newUnit in
            gramsText = newUnit.displayText(fromGrams: candidate.portion.gramsMode)
        }
    }

    private var gramsField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("0", text: gramsBinding)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80, maxWidth: 126)
                .focused($isGramsFieldFocused)
                .accessibilityLabel("Portion \(unit.fieldLabel)")
                .accessibilityIdentifier("PortionGramsField")
                .onSubmit(onCommit)

            Text(unit.shortLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.clear)
                .mealMarkGlassSurface(
                    cornerRadius: 18,
                    tint: Color.secondary.opacity(0.08),
                    isInteractive: true
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func commitAndDismiss() {
        onCommit()
        isGramsFieldFocused = false
        MealMarkKeyboard.dismiss()
    }

    private var gramsBinding: Binding<String> {
        Binding {
            gramsText
        } set: { newValue in
            gramsText = sanitizedAmount(newValue)
        }
    }

    private func update(to grams: Int64) {
        gramsText = unit.displayText(fromGrams: grams)
    }

    private func sanitizedAmount(_ value: String) -> String {
        var output = ""
        var hasDecimalSeparator = false
        for character in value {
            if character.isNumber {
                output.append(character)
            } else if (character == "." || character == ","), !hasDecimalSeparator {
                output.append(".")
                hasDecimalSeparator = true
            }
        }
        return output
    }

    private func portionButton(
        symbol: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 50, height: 50)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private struct RunningGrainRefreshView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRunning = false

    var body: some View {
        HStack(spacing: 10) {
            RunningGrainMascot(isRunning: isRunning && !reduceMotion)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            Text("Refreshing")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .mealMarkGlassSurface(cornerRadius: 24, tint: Color.green.opacity(0.1), isInteractive: false)
        .accessibilityLabel("Refreshing MealMark")
        .accessibilityIdentifier("RefreshGrainMascot")
        .onAppear {
            guard !reduceMotion else {
                return
            }
            withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) {
                isRunning = true
            }
        }
        .onDisappear {
            isRunning = false
        }
    }
}

private struct RunningGrainMascot: View {
    var isRunning: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.12))
                    .frame(width: width * 0.66, height: height * 0.12)
                    .offset(y: height * 0.35)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.sRGB, red: 1.0, green: 0.82, blue: 0.38, opacity: 1),
                                Color(.sRGB, red: 0.95, green: 0.59, blue: 0.24, opacity: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width * 0.48, height: height * 0.7)
                    .rotationEffect(.degrees(isRunning ? -12 : -7))
                    .offset(x: width * 0.02, y: isRunning ? -height * 0.05 : height * 0.02)
                    .shadow(color: .green.opacity(0.16), radius: 5, x: 0, y: 3)

                Capsule()
                    .fill(Color.green.opacity(0.78))
                    .frame(width: width * 0.14, height: height * 0.32)
                    .rotationEffect(.degrees(38))
                    .offset(x: width * 0.18, y: -height * 0.26)

                HStack(spacing: width * 0.11) {
                    Circle()
                        .fill(.black.opacity(0.75))
                    Circle()
                        .fill(.black.opacity(0.75))
                }
                .frame(width: width * 0.24, height: height * 0.07)
                .offset(x: width * 0.02, y: -height * 0.09)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.42, y: height * 0.54))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.6, y: height * 0.54),
                        control: CGPoint(x: width * 0.51, y: height * 0.62)
                    )
                }
                .stroke(.black.opacity(0.58), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                HStack(spacing: width * 0.28) {
                    Capsule()
                        .fill(Color.green.opacity(0.76))
                        .frame(width: width * 0.1, height: height * 0.27)
                        .rotationEffect(.degrees(isRunning ? 24 : -22))
                    Capsule()
                        .fill(Color.green.opacity(0.76))
                        .frame(width: width * 0.1, height: height * 0.27)
                        .rotationEffect(.degrees(isRunning ? -22 : 24))
                }
                .offset(y: height * 0.35)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var editingEntry: EditableMealEntry?
    @State private var isRefreshing = false

    var body: some View {
        ZStack(alignment: .top) {
            List {
                if store.entries.isEmpty {
                    Section {
                        EmptyStateView(
                            title: "History is empty",
                            symbol: "calendar",
                            message: "Confirmed MealMark records will appear here."
                        )
                    }
                } else {
                    ForEach(historyGroups) { group in
                        Section {
                            ForEach(group.entries, id: \.entryID) { entry in
                                NavigationLink {
                                    MealDetailView(entryID: entry.entryID)
                                } label: {
                                    MealRow(entry: entry, showsTime: true)
                                }
                                .mealEntrySwipeActions(
                                    entry: entry,
                                    onEdit: { editingEntry = EditableMealEntry(entry: entry) }
                                )
                            }
                        } header: {
                            HistoryDayHeaderView(group: group)
                        }
                    }
                }
            }
            .refreshable {
                await refreshLocalState()
            }

            if isRefreshing {
                RunningGrainRefreshView()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
        .navigationTitle("History")
        .sheet(item: $editingEntry) { editableEntry in
            EditMealEntryView(entry: editableEntry.entry)
        }
    }

    private var historyGroups: [HistoryDayGroup] {
        Dictionary(grouping: store.entries, by: \.dateKey)
            .map { dateKey, entries in
                HistoryDayGroup(
                    dateKey: dateKey,
                    entries: entries.sorted { $0.confirmedAt > $1.confirmedAt }
                )
            }
            .sorted {
                ($0.entries.first?.confirmedAt ?? .distantPast) >
                    ($1.entries.first?.confirmedAt ?? .distantPast)
            }
    }

    private func refreshLocalState() async {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        await store.refreshLocalState()
        try? await Task.sleep(nanoseconds: 650_000_000)
        isRefreshing = false
    }
}

private struct HistoryDayGroup: Identifiable {
    var dateKey: String
    var entries: [FoodIntakeEntry]
    var id: String { dateKey }
}

private struct HistoryDayHeaderView: View {
    var group: HistoryDayGroup

    private var totalKcal: Int64 {
        group.entries.reduce(0) { $0 + $1.meal.kcal }
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(group.entries.count) items • \(totalKcal) kcal")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .accessibilityIdentifier("HistoryDayHeader-\(group.dateKey)")
    }

    private var title: String {
        guard let date = Self.dateFormatter.date(from: group.dateKey) else {
            return group.dateKey
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct EditableMealEntry: Identifiable {
    var entry: FoodIntakeEntry
    var id: String { entry.entryID }
}

private struct EditMealEntryView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var labelText: String
    @State private var gramsText: String
    @State private var errorMessage: String?

    private let entry: FoodIntakeEntry

    private enum Field {
        case label
        case grams
    }

    init(entry: FoodIntakeEntry) {
        self.entry = entry
        _labelText = State(initialValue: entry.meal.label)
        _gramsText = State(initialValue: "\(entry.meal.amountGrams)")
    }

    private var trimmedLabel: String {
        labelText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var gramsValue: Int64? {
        Int64(gramsText.filter(\.isNumber))
    }

    private var previewMeal: MealEstimate {
        let grams = max(1, gramsValue ?? entry.meal.amountGrams)
        let factor = Double(grams) / Double(max(1, entry.meal.amountGrams))
        return MealEstimate(
            label: trimmedLabel.isEmpty ? entry.meal.label : trimmedLabel,
            kcal: max(0, Int64((Double(entry.meal.kcal) * factor).rounded())),
            varianceKcal: max(0, Int64((Double(entry.meal.varianceKcal) * factor).rounded())),
            amountGrams: grams,
            servingGrams: grams,
            servings: entry.meal.servings,
            macronutrients: entry.meal.macronutrients?.scaled(by: factor)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Food") {
                    TextField("Food name", text: $labelText)
                        .focused($focusedField, equals: .label)
                        .accessibilityIdentifier("EditMealNameField")

                    HStack {
                        TextField("Grams", text: gramsBinding)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .focused($focusedField, equals: .grams)
                            .accessibilityIdentifier("EditMealGramsField")
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preview") {
                    LabeledContent("Calories", value: "\(previewMeal.kcal) kcal")
                    if let macronutrients = previewMeal.macronutrients {
                        LabeledContent("Macros", value: macronutrients.shortLabel)
                    }
                    Text("MealMark keeps the original source and updates the serving you ate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("EditMealErrorLabel")
                    }
                }
            }
            .mealMarkScrollDismissesKeyboard()
            .navigationTitle("Edit meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CancelEditMealButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(trimmedLabel.isEmpty || (gramsValue ?? 0) <= 0)
                    .accessibilityIdentifier("SaveEditedMealButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    MealMarkKeyboardDoneButton(accessibilityIdentifier: "EditMealKeyboardDoneButton") {
                        focusedField = nil
                        MealMarkKeyboard.dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = .grams
            }
        }
    }

    private var gramsBinding: Binding<String> {
        Binding {
            gramsText
        } set: { newValue in
            gramsText = String(newValue.filter(\.isNumber))
        }
    }

    private func save() {
        guard let grams = gramsValue, grams > 0 else {
            errorMessage = "Enter grams greater than zero."
            return
        }
        guard !trimmedLabel.isEmpty else {
            errorMessage = "Add a food name."
            return
        }
        guard store.updateEntry(entryID: entry.entryID, label: trimmedLabel, gramsMode: grams) else {
            errorMessage = "MealMark could not update this record."
            return
        }
        dismiss()
    }
}

private extension View {
    func mealEntrySwipeActions(entry: FoodIntakeEntry, onEdit: @escaping () -> Void) -> some View {
        modifier(MealEntrySwipeActions(entry: entry, onEdit: onEdit))
    }
}

private struct MealEntrySwipeActions: ViewModifier {
    @EnvironmentObject private var store: FoodWalletStore
    var entry: FoodIntakeEntry
    var onEdit: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    _ = store.deleteEntry(entryID: entry.entryID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("DeleteMealButton-\(entry.entryID)")

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
                .accessibilityIdentifier("EditMealButton-\(entry.entryID)")
            }
    }
}

private struct MealDetailView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingEntry: EditableMealEntry?
    var entryID: String

    private var entry: FoodIntakeEntry? {
        store.entry(entryID: entryID)
    }

    var body: some View {
        Group {
            if let entry {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.meal.label)
                                        .font(.title2.bold())
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("MealDetailTitle")
                                    Text("\(entry.meal.amountGrams) g • \(entry.meal.kcal) kcal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("MealDetailNutrition")
                                }
                                Spacer()
                                SourceBadge(text: entry.trustStatus.label, tint: entry.trustStatus.reviewTint)
                            }

                            if let macronutrients = entry.meal.macronutrients {
                                Text(macronutrients.shortLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("MealDetailMacros")
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Section("Nutrition") {
                        LabeledContent("Calories", value: "\(entry.meal.kcal) kcal")
                        LabeledContent("Range", value: "\(max(0, entry.meal.kcal - entry.meal.varianceKcal))-\(entry.meal.kcal + entry.meal.varianceKcal) kcal")
                        LabeledContent("Grams", value: "\(entry.meal.amountGrams) g")
                        LabeledContent("Servings", value: "\(entry.meal.servings)")
                    }

                    if let macronutrients = entry.meal.macronutrients {
                        Section("Macros") {
                            LabeledContent("Protein", value: macroValue(macronutrients.proteinGrams))
                            LabeledContent("Carbs", value: macroValue(macronutrients.carbohydrateGrams))
                            LabeledContent("Fat", value: macroValue(macronutrients.fatGrams))
                            if let fiberGrams = macronutrients.fiberGrams {
                                LabeledContent("Fiber", value: macroValue(fiberGrams))
                            }
                        }
                    }

                    Section("How MealMark read it") {
                        LabeledContent("Source", value: entry.sourceClass.description)
                        LabeledContent("Trust", value: entry.trustStatus.label)
                        if let provenance = store.provenanceSnapshot(entryID: entry.entryID) {
                            ForEach(Array(provenance.evidence.enumerated()), id: \.offset) { _, evidence in
                                MealDetailEvidenceRow(evidence: evidence)
                            }
                        } else {
                            Text("This entry keeps confirmed nutrition values and trust labels. Detailed provider evidence is available for meals saved in the current session.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Record") {
                        LabeledContent("Date", value: entry.dateKey)
                        LabeledContent("Saved", value: entry.confirmedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Entry ID", value: entry.entryID)
                    }
                }
                .accessibilityIdentifier("MealDetailScreen")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            editingEntry = EditableMealEntry(entry: entry)
                        }
                        .accessibilityIdentifier("MealDetailEditButton")
                    }
                }
            } else {
                EmptyStateView(
                    title: "Meal not found",
                    symbol: "exclamationmark.magnifyingglass",
                    message: "This record is no longer available."
                )
            }
        }
        .navigationTitle("Meal details")
        .mealMarkNavigationBarTitleDisplayModeInline()
        .sheet(item: $editingEntry) { editableEntry in
            EditMealEntryView(entry: editableEntry.entry)
        }
    }

    private func macroValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) g"
        }
        return "\(rounded) g"
    }
}

private struct MealDetailEvidenceRow: View {
    var evidence: ProviderEvidence

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(evidence.sourceLabel)
                    .font(.subheadline.weight(.semibold))
                Text("\(evidence.matchedName) • \(evidence.servingBasis)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailLabel {
                    Text(detailLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityIdentifier("MealDetailEvidence-\(evidence.normalizedProvider)")
    }

    private var detailLabel: String? {
        let parts = [
            evidence.trustLabel,
            evidence.matchType,
            evidence.providerID.isEmpty ? nil : "ID \(evidence.providerID)",
        ].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: " • ")
    }

    private var iconName: String {
        switch evidence.normalizedProvider {
        case "visible_nutrition_label":
            return "doc.text.viewfinder"
        case "barcode_provider", "open_food_facts":
            return "barcode.viewfinder"
        case "usda_fdc":
            return "books.vertical"
        case "food_wallet_history":
            return "clock.arrow.circlepath"
        case "food_wallet_recipe", "food_wallet_template":
            return "book.closed"
        default:
            return "checkmark.seal"
        }
    }
}

private struct WalletView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var isShowingBackupImporter = false
    @State private var restoreDraft: RestoreDraft?
    @State private var restoreStatusMessage: String?
    @State private var restoreErrorMessage: String?

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

            Section("Export") {
                ShareLink(item: portableJSONText) {
                    Label("Export portable JSON", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("ExportPortableJSONButton")

                ShareLink(item: store.exportCSV()) {
                    Label("Export CSV", systemImage: "tablecells")
                }
                .accessibilityIdentifier("ExportCSVButton")

                ShareLink(item: grainBundleText) {
                    Label("Export Grain bundle", systemImage: "shippingbox")
                }
                .accessibilityIdentifier("ExportGrainBundleButton")

                Text("Exports include confirmed food data, templates, recipes, and redacted provenance only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ExportPrivacyLabel")
            }

            Section("Import") {
                Button {
                    isShowingBackupImporter = true
                } label: {
                    Label("Choose Grain bundle", systemImage: "doc.badge.plus")
                }
                .accessibilityIdentifier("ChooseBackupFileButton")

                Button {
                    previewLatestBackup()
                } label: {
                    Label("Preview saved local data", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!FoodWalletLocalLedgerStore.hasBackup)
                .accessibilityIdentifier("PreviewLatestBackupButton")

                if let restoreDraft {
                    RestorePreviewView(draft: restoreDraft)

                    Button {
                        applyRestore(restoreDraft)
                    } label: {
                        Label("Import new entries", systemImage: "arrow.clockwise.circle")
                    }
                    .disabled(restoreDraft.preview.newEntryCount == 0)
                    .accessibilityIdentifier("ApplyRestoreButton")
                }

                if let restoreStatusMessage {
                    Text(restoreStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("RestoreStatusLabel")
                }

                if let restoreErrorMessage {
                    Text(restoreErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("RestoreErrorLabel")
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
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImport
        )
    }

    private var portableJSONText: String {
        guard let data = try? store.exportPortableJSON(),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private var grainBundleText: String {
        portableJSONText
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try previewBackup(data: Data(contentsOf: url))
        } catch {
            restoreDraft = nil
            restoreStatusMessage = nil
            restoreErrorMessage = "That Grain bundle could not be read."
        }
    }

    private func previewLatestBackup() {
        guard let bundle = FoodWalletLocalLedgerStore.loadBundle() else {
            restoreDraft = nil
            restoreStatusMessage = nil
            restoreErrorMessage = "No saved local data is available yet."
            return
        }
        do {
            try previewBackup(bundle: bundle)
        } catch {
            restoreDraft = nil
            restoreStatusMessage = nil
            restoreErrorMessage = "Saved local data could not be previewed."
        }
    }

    private func previewBackup(data: Data) throws {
        let bundle = try FoodWalletExportFactory.decodeBundle(data)
        try previewBackup(bundle: bundle)
    }

    private func previewBackup(bundle: FoodWalletExportBundle) throws {
        let preview = try store.previewPortableImport(bundle)
        restoreDraft = RestoreDraft(bundle: bundle, preview: preview)
        restoreStatusMessage = nil
        restoreErrorMessage = nil
    }

    private func applyRestore(_ draft: RestoreDraft) {
        do {
            let result = try store.importPortableBundle(draft.bundle)
            restoreStatusMessage = "\(result.importedEntryCount) imported • \(result.duplicateEntryCount) already saved"
            restoreErrorMessage = nil
            restoreDraft = nil
        } catch {
            restoreStatusMessage = nil
            restoreErrorMessage = "That Grain bundle could not be imported."
        }
    }
}

private struct RestoreDraft {
    var bundle: FoodWalletExportBundle
    var preview: FoodWalletImportPreview
}

private struct RestorePreviewView: View {
    var draft: RestoreDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("RestorePreviewSummary")
            Text("Review first. Nothing changes until you restore new entries.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !sourceSummary.isEmpty {
                Text(sourceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("RestorePreviewSourceSummary")
            }
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        "\(draft.preview.entryCount) \(entryNoun(draft.preview.entryCount)) in bundle • \(draft.preview.newEntryCount) new • \(draft.preview.duplicateEntryCount) already saved"
    }

    private var sourceSummary: String {
        draft.preview.trustStatusSummary
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: " • ")
    }

    private func entryNoun(_ count: Int) -> String {
        count == 1 ? "entry" : "entries"
    }
}

private struct ProView: View {
    @EnvironmentObject private var store: FoodWalletStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MealMark Pro")
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
    var showsTime = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.meal.label)
                        .font(.headline)
                        .accessibilityIdentifier("MealRowLabel-\(entry.meal.label)")
                    if showsTime {
                        Text(entry.confirmedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("MealRowTime-\(entry.entryID)")
                    }
                }
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
            SourceBadge(text: entry.trustStatus.label, tint: entry.trustStatus.reviewTint)
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

private extension FoodAnalysisCandidate {
    func reviewBadgeText(trustStatus: FoodTrustStatus) -> String {
        if trustStatus == .verified {
            return "Verified"
        }

        let providers = Set(evidence.map(\.provider))
        if providers.contains("visible_nutrition_label") {
            return "Label read"
        }
        let sourceIDs = Set(evidence.compactMap(\.sourceLabelID).map(FoodEvidenceSource.normalize))
        if sourceIDs.contains("barcode_provider") {
            return "Barcode match"
        }
        if providers.contains("open_food_facts") {
            return "Barcode match"
        }
        if providers.contains("food_wallet_template") {
            return "Template"
        }
        if providers.contains("food_wallet_recipe") {
            return "Recipe"
        }
        if providers.contains("food_wallet_history") {
            return "Recent"
        }
        if providers.contains("usda_fdc") {
            return "USDA estimate"
        }
        return trustStatus.label
    }
}

private extension FoodTrustStatus {
    var reviewTint: Color {
        switch self {
        case .verified:
            return .green
        case .selfIssued:
            return .blue
        case .estimated:
            return .orange
        case .untrusted:
            return .red
        }
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
