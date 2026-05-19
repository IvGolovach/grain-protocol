import FoodWalletCore
import Foundation
import GrainFoodWallet
import SwiftUI
import UniformTypeIdentifiers

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

private enum FoodWalletHaptics {
    @MainActor
    static func selectionChanged() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

struct FoodWalletRootView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var selectedTab: FoodWalletTab = .today
    @State private var isShowingCamera = false
    @State private var isShowingAddFoodHub = false
    @State private var captureErrorMessage: String?

    private var usesUITestPhotoFlow: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--grain-ui-test-photo-flow") ||
            arguments.contains("--grain-ui-test-delayed-photo-flow") ||
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

            if store.analysisState.isAnalyzing {
                AnalysisProgressOverlay(state: store.analysisState) {
                    store.cancelAnalysis()
                }
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
                        selectedTab = .capture
                    },
                    onTakePhoto: {
                        isShowingAddFoodHub = false
                        selectedTab = .capture
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            startPhotoCaptureFlow()
                        }
                    }
                )
            }
        }
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

    private var tabContent: some View {
        TabView(selection: tabSelection) {
            NavigationStack {
                TodayView(onAddFood: openAddFoodHub)
            }
            .tabItem { Label(FoodWalletTab.today.title, systemImage: FoodWalletTab.today.symbol) }
            .tag(FoodWalletTab.today)

            NavigationStack {
                CaptureView(onCapturePhoto: startPhotoCaptureFlow)
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
    }

    private func openAddFoodHub() {
        selectedTab = .capture

        if usesUITestPhotoFlow {
            Task {
                await store.analyze(photo: .uiTestFujiApple)
            }
            return
        }

        isShowingAddFoodHub = true
    }

    private func startPhotoCaptureFlow() {
        selectedTab = .capture

        #if os(iOS)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingCamera = true
        } else {
            captureErrorMessage = "This device does not expose a camera to MealMark. Use a real iPhone for camera capture."
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
                    Text("MealMark")
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
    var onCapturePhoto: () -> Void

    var body: some View {
        List {
            Section {
                Text("Photo creates a draft. You decide what gets saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Review draft") {
                if let errorMessage = store.analysisState.errorMessage {
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
                        message: "Analyze a sample photo to create a MealMark draft."
                    )
                }
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
        }
        .navigationTitle("Capture")
    }
}

private struct IngredientBuilderRow: Identifiable {
    let id = UUID()
    var name = ""
    var grams = ""
}

private enum AddFoodRoute: Hashable {
    case buildMeal
}

private struct AddFoodHubView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: AddFoodFocus?
    @State private var quickText = ""
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

    var onDraftReady: () -> Void
    var onTakePhoto: () -> Void

    private var latestEntry: FoodIntakeEntry? {
        store.entries.first
    }

    private var trimmedQuickText: String {
        quickText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchQuery: Bool {
        !trimmedQuickText.isEmpty
    }

    private var previousDateKey: String? {
        let today = Self.utcDateKey(for: Date())
        return store.entries.first { $0.dateKey != today }?.dateKey
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    AddFoodShortcutGrid(
                        canStartPhoto: store.canStartAnalysis,
                        hasQuickText: hasSearchQuery,
                        onPhoto: onTakePhoto,
                        onBarcode: {
                            isShowingBarcodeLookup = true
                        },
                        onQuickAdd: startQuickAdd
                    )

                    AddFoodSearchField(
                        text: $quickText,
                        focusedField: $focusedField,
                        onSubmit: createQuickTextDraft
                    )

                    if hasSearchQuery {
                        AddFoodScopeBar(selectedScope: $selectedScope)
                    }

                    if shouldShowFoodSearchResults {
                        ForEach(Array(filteredFoodSearchRows.prefix(3).enumerated()), id: \.element.id) { index, row in
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

                    if shouldShowQuickCreateRow {
                        AddFoodResultRow(
                            title: "Create \"\(trimmedQuickText)\"",
                            subtitle: "Local estimate, ready for review",
                            symbol: "text.badge.plus",
                            accessibilityIdentifier: "FoodSearchResult-\(Self.slug(trimmedQuickText))",
                            action: createQuickTextDraft
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Choose how to add")
            } footer: {
                Text("Choose photo, barcode, quick add, or build a meal. Search appears after you type.")
            }

            if shouldShowBrowseResultsSection {
                Section(resultsSectionTitle) {
                    if shouldShowPresetSuggestions {
                        ForEach(Self.quickDraftSuggestions, id: \.self) { suggestion in
                            AddFoodResultRow(
                                title: suggestion,
                                subtitle: "Create a local quick draft",
                                symbol: "sparkle.magnifyingglass",
                                accessibilityIdentifier: "QuickSuggestion-\(Self.slug(suggestion))"
                            ) {
                                createQuickTextDraft(suggestion)
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
                }
            }

            if hasSearchQuery, let latestEntry {
                Section("Repeat") {
                    CaptureAction(
                        title: "Repeat \(latestEntry.meal.label)",
                        subtitle: "\(latestEntry.meal.amountGrams) g • \(latestEntry.meal.kcal) kcal",
                        symbol: "clock.arrow.circlepath",
                        accessibilityIdentifier: "RepeatLastMealButton"
                    ) {
                        createRecentDraft(entryID: latestEntry.entryID)
                    }
                }
            }

            if hasSearchQuery {
                Section("Previous day") {
                    if let previousDateKey {
                        Button {
                            if store.copyEntries(fromDateKey: previousDateKey) > 0 {
                                dismiss()
                            }
                        } label: {
                            Label("Copy previous day", systemImage: "calendar.badge.plus")
                        }
                        .accessibilityIdentifier("CopyPreviousDayButton")
                    } else {
                        Label("No previous day yet", systemImage: "calendar")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Add Food")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .navigationDestination(for: AddFoodRoute.self) { route in
            switch route {
            case .buildMeal:
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
        }
        .sheet(isPresented: $isShowingBarcodeLookup) {
            NavigationStack {
                BarcodeLookupView(onDraftReady: onDraftReady)
            }
        }
    }

    private static let quickDraftSuggestions = [
        "2 eggs and toast",
        "Apple",
        "Salad bowl",
    ]

    private static func utcDateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func slug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private var canCreateIngredientDraft: Bool {
        !mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            ingredientRows.contains { row in
                !row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    (Int64(row.grams.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
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

    private var filteredFoodSearchRows: [AddFoodSuggestionRow] {
        guard hasSearchQuery, selectedScope == .all || selectedScope == .myFoods else {
            return []
        }
        return store.addFoodSearchSuggestions(for: trimmedQuickText)
    }

    private var shouldShowFoodSearchResults: Bool {
        !filteredFoodSearchRows.isEmpty
    }

    private var shouldShowQuickCreateRow: Bool {
        hasSearchQuery && selectedScope == .all && !shouldShowFoodSearchResults
    }

    private var shouldShowPresetSuggestions: Bool {
        false
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
        !shouldShowQuickCreateRow &&
            !shouldShowPresetSuggestions &&
            !shouldShowFoodSearchResults &&
            !shouldShowRecentResults &&
            !shouldShowTemplateResults &&
            !shouldShowRecipeResults &&
            !shouldShowPersonalFoodResults
    }

    private var shouldShowBrowseResultsSection: Bool {
        hasSearchQuery && (shouldShowPresetSuggestions ||
            shouldShowRecentResults ||
            shouldShowTemplateResults ||
            shouldShowRecipeResults ||
            shouldShowPersonalFoodResults ||
            shouldShowEmptyResults)
    }

    private var resultsSectionTitle: String {
        hasSearchQuery ? "Results" : "Suggestions"
    }

    private var emptyResultsTitle: String {
        if hasSearchQuery {
            return "No matches"
        }
        return selectedScope.emptyTitle
    }

    private var emptyResultsMessage: String {
        if hasSearchQuery {
            return "Try All, or use the search text as a local quick draft."
        }
        return selectedScope.emptyMessage
    }

    private func matches(_ primary: String, secondary: String? = nil) -> Bool {
        guard hasSearchQuery else {
            return false
        }
        return primary.localizedCaseInsensitiveContains(trimmedQuickText) ||
            (secondary?.localizedCaseInsensitiveContains(trimmedQuickText) ?? false)
    }

    private func startQuickAdd() {
        guard hasSearchQuery else {
            focusedField = .search
            return
        }
        createQuickTextDraft()
    }

    private func createQuickTextDraft() {
        createQuickTextDraft(trimmedQuickText)
    }

    private func createQuickTextDraft(_ text: String) {
        guard store.createQuickTextDraft(text) else {
            return
        }
        onDraftReady()
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
                grams: Int64(row.grams.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
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
            ingredientErrorMessage = "Check grams for \(name)."
        case let .unknownIngredient(name):
            ingredientErrorMessage = "Add nutrition for \(name) once, then use it in meals."
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

    private func decimalValue(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func foodSearchAccessibilityIdentifier(for row: AddFoodSuggestionRow, index: Int) -> String {
        if index == 0, hasSearchQuery {
            return "FoodSearchResult-\(Self.slug(trimmedQuickText))"
        }
        return "FoodSearchResult-\(Self.slug(row.title))"
    }
}

private struct BuildMealEditorView: View {
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
            Section {
                TextField("Meal name", text: $mealTitle)
                    .accessibilityIdentifier("MealTitleField")

                ForEach(ingredientRows.indices, id: \.self) { index in
                    IngredientBuilderRowView(
                        index: index,
                        row: $ingredientRows[index]
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
                Button(action: onCreateDraft) {
                    Label("Create meal draft", systemImage: "fork.knife.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!canCreateIngredientDraft)
                .accessibilityIdentifier("CreateIngredientMealDraftButton")
            }
        }
        .navigationTitle("Build Meal")
        .accessibilityIdentifier("BuildMealScreen")
    }
}

private struct BarcodeLookupView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var barcodeText = ""
    @State private var errorMessage: String?
    @State private var isLookingUp = false
    @State private var detectedBarcode: String?

    var onDraftReady: () -> Void

    private var normalizedBarcode: String? {
        BrokerFoodSearchRequest.normalizeBarcode(barcodeText)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    BarcodeScannerView { barcode in
                        handleDetectedBarcode(barcode)
                    }
                    .frame(minHeight: 190)

                    if let detectedBarcode {
                        Label("Detected \(detectedBarcode)", systemImage: "barcode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("BarcodeDetectedValueLabel")
                    }

                    TextField("Enter UPC or EAN", text: $barcodeText)
                        .textContentType(.oneTimeCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("BarcodeManualEntryField")

                    Button(action: lookupManualBarcode) {
                        if isLookingUp {
                            Label("Looking up", systemImage: "hourglass")
                        } else {
                            Label("Look up barcode", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(normalizedBarcode == nil || isLookingUp)
                    .accessibilityIdentifier("BarcodeManualLookupButton")

                    statusLabel
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Packaged foods use broker-side databases. You still review serving size before saving.")
            }
        }
        .navigationTitle("Barcode")
        .accessibilityIdentifier("BarcodeScannerSheet")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("BarcodeCancelButton")
            }
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
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("BarcodeLookupErrorLabel")
        } else {
            Text("Use the camera or type the digits printed under the barcode.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("BarcodeLookupStatusLabel")
        }
    }

    private func handleDetectedBarcode(_ value: String) {
        let normalized = BrokerFoodSearchRequest.normalizeBarcode(value) ?? value
        detectedBarcode = normalized
        barcodeText = normalized
        Task {
            await lookupBarcode(normalized)
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

        guard case .ready = store.foodSearchState,
              let firstResult = store.brokerFoodSearchRows.first,
              store.createBrokerFoodSearchDraft(id: firstResult.id) else {
            errorMessage = "No trusted match yet. Try photo or quick add."
            return
        }
        onDraftReady()
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
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityLabel("FoodSearchField")
                .accessibilityIdentifier("QuickTextField")

            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
            }
            .disabled(trimmedText.isEmpty)
            .accessibilityLabel("Create quick draft")
            .accessibilityIdentifier("CreateQuickDraftButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AddFoodShortcutGrid: View {
    var canStartPhoto: Bool
    var hasQuickText: Bool
    var onPhoto: () -> Void
    var onBarcode: () -> Void
    var onQuickAdd: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            AddFoodShortcutButton(
                title: "Photo",
                subtitle: canStartPhoto ? "Analyze a plate" : "Analysis is unavailable now",
                symbol: "camera.fill",
                accessibilityIdentifier: "AddFoodModePhotoButton",
                isEnabled: canStartPhoto,
                action: onPhoto
            )

            AddFoodShortcutButton(
                title: "Barcode",
                subtitle: "Scan packaged food",
                symbol: "barcode.viewfinder",
                accessibilityIdentifier: "AddFoodModeBarcodeButton",
                action: onBarcode
            )

            AddFoodShortcutButton(
                title: "Quick Add",
                subtitle: hasQuickText ? "Create local draft" : "Type food first",
                symbol: "plus.circle.fill",
                accessibilityIdentifier: "AddFoodModeQuickAddButton",
                action: onQuickAdd
            )

            NavigationLink(value: AddFoodRoute.buildMeal) {
                AddFoodShortcutTile(
                    title: "Build Meal",
                    subtitle: "Ingredients and grams",
                    symbol: "list.bullet.clipboard",
                    isEnabled: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("AddFoodModeBuildMealButton")
        }
        .accessibilityIdentifier("AddFoodModeChooser")
    }
}

private struct AddFoodShortcutButton: View {
    var title: String
    var subtitle: String
    var symbol: String
    var accessibilityIdentifier: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AddFoodShortcutTile(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                isEnabled: isEnabled
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(10)
        .background(isEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct IngredientBuilderRowView: View {
    var index: Int
    @Binding var row: IngredientBuilderRow

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ingredient", text: $row.name)
                .accessibilityIdentifier("IngredientNameField-\(index)")

            TextField("g", text: $row.grams)
                .frame(width: 72)
                .accessibilityIdentifier("IngredientGramsField-\(index)")
        }
    }
}

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

            HStack(spacing: 10) {
                TextField("serving g", text: $servingGrams)
                    .accessibilityIdentifier("PersonalIngredientServingGramsField")
                TextField("kcal", text: $servingKcal)
                    .accessibilityIdentifier("PersonalIngredientCaloriesField")
            }

            HStack(spacing: 10) {
                TextField("protein", text: $proteinGrams)
                    .accessibilityIdentifier("PersonalIngredientProteinField")
                TextField("carbs", text: $carbohydrateGrams)
                    .accessibilityIdentifier("PersonalIngredientCarbsField")
            }

            HStack(spacing: 10) {
                TextField("fat", text: $fatGrams)
                    .accessibilityIdentifier("PersonalIngredientFatField")
                TextField("fiber", text: $fiberGrams)
                    .accessibilityIdentifier("PersonalIngredientFiberField")
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

    var body: some View {
        if let candidate = store.currentCandidate {
            let trustStatus = store.currentDraft?.trustStatus ?? .estimated
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
                    SourceBadge(
                        text: candidate.reviewBadgeText(trustStatus: trustStatus),
                        tint: trustStatus.reviewTint
                    )
                }

                Label(candidate.confidence.label, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline)

                PortionControlsView(
                    candidate: candidate,
                    gramsText: $portionGramsText,
                    onCommit: commitPortion
                )

                HStack {
                    Button(role: .cancel) {
                        store.discardDraft()
                    } label: {
                        Label("Discard", systemImage: "xmark")
                    }

                    Spacer()

                    Button {
                        commitPortion()
                        store.confirmDraft()
                    } label: {
                        Label("Save to MealMark", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!store.canSaveDraft)
                    .accessibilityIdentifier("SaveToFoodWalletButton")
                }
            }
            .padding(.vertical, 8)
            .onAppear {
                resetPortionText(with: candidate)
            }
            .onChange(of: candidate.id) { _ in
                resetPortionText(with: candidate)
            }
            .onChange(of: candidate.portion.gramsMode) { gramsMode in
                portionGramsText = "\(gramsMode)"
            }
        }
    }

    private func commitPortion() {
        guard let candidate = store.currentCandidate else {
            return
        }
        let digits = Self.digitsOnly(portionGramsText)
        guard let grams = Int64(digits), grams > 0 else {
            portionGramsText = "\(candidate.portion.gramsMode)"
            return
        }
        if grams != candidate.portion.gramsMode {
            _ = store.updateCurrentDraftPortion(gramsMode: grams)
        }
        portionGramsText = "\(grams)"
    }

    private func resetPortionText(with candidate: FoodAnalysisCandidate) {
        portionGramsText = "\(candidate.portion.gramsMode)"
    }

    private static func digitsOnly(_ text: String) -> String {
        String(text.filter(\.isNumber))
    }
}

private struct PortionControlsView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @FocusState private var isGramsFieldFocused: Bool
    var candidate: FoodAnalysisCandidate
    @Binding var gramsText: String
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Portion")
                .font(.headline)

            HStack(alignment: .center, spacing: 10) {
                Button {
                    update(to: max(1, candidate.portion.gramsMode - 25))
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Decrease portion")
                .accessibilityIdentifier("PortionDecreaseButton")

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: gramsBinding)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 74, maxWidth: 108)
                        .focused($isGramsFieldFocused)
                        .accessibilityLabel("Portion grams")
                        .accessibilityIdentifier("PortionGramsField")

                    Text("g")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    update(to: candidate.portion.gramsMode + 25)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Increase portion")
                .accessibilityIdentifier("PortionIncreaseButton")

                Button {
                    onCommit()
                } label: {
                    Text("Set")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ApplyPortionGramsButton")
            }

            Button {
                update(to: max(1, candidate.portion.gramsMode / 2))
            } label: {
                Label("Half", systemImage: "divide")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("PortionHalfButton")
        }
        .onChange(of: isGramsFieldFocused) { isFocused in
            if isFocused && gramsText == "\(candidate.portion.gramsMode)" {
                gramsText = ""
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

    private func update(to grams: Int64) {
        _ = store.updateCurrentDraftPortion(gramsMode: grams)
        gramsText = "\(grams)"
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
                        message: "Confirmed MealMark records will appear here."
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

private extension FoodAnalysisCandidate {
    func reviewBadgeText(trustStatus: FoodTrustStatus) -> String {
        if trustStatus == .verified {
            return "Verified"
        }

        let providers = Set(evidence.map(\.provider))
        if providers.contains("visible_nutrition_label") {
            return "Label read"
        }
        if providers.contains("open_food_facts_fixture") || providers.contains("open_food_facts") {
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
        if providers.contains("food_wallet_quick_text") {
            return "Quick add"
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
