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
    @State private var addFoodHubDetent = PresentationDetent.medium
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
            .presentationDetents([.medium, .large], selection: $addFoodHubDetent)
            .presentationDragIndicator(.visible)
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
                CaptureView(
                    onCapturePhoto: startPhotoCaptureFlow,
                    onEnterManually: openAddFoodHub
                )
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
        addFoodHubDetent = .medium

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
    @State private var editingEntry: EditableMealEntry?
    @State private var isRefreshing = false
    var onAddFood: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
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

private struct CaptureView: View {
    @EnvironmentObject private var store: FoodWalletStore
    var onCapturePhoto: () -> Void
    var onEnterManually: () -> Void

    var body: some View {
        List {
            Section {
                Text("Photo creates a draft. You decide what gets saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Review draft") {
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
                    DraftReviewView()
                } else {
                    EmptyStateView(
                        title: "No active draft",
                        symbol: "doc.text.magnifyingglass",
                        message: "Take a meal photo to create a reviewable MealMark draft."
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
    @State private var isShowingBuildMeal = false

    var onDraftReady: () -> Void
    var onTakePhoto: () -> Void

    private var trimmedQuickText: String {
        quickText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchQuery: Bool {
        !trimmedQuickText.isEmpty
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    AddFoodSearchField(
                        text: $quickText,
                        focusedField: $focusedField,
                        onSubmit: createQuickTextDraft
                    )

                    AddFoodShortcutGrid(
                        canStartPhoto: store.canStartAnalysis,
                        onPhoto: onTakePhoto,
                        onBarcode: {
                            isShowingBarcodeLookup = true
                        },
                        onBuild: {
                            isShowingBuildMeal = true
                        }
                    )
                }
                .padding(.vertical, 4)
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
                        ForEach(Array(filteredFoodSearchRows.prefix(4).enumerated()), id: \.element.id) { index, row in
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

                    if shouldShowQuickCreateRow {
                        AddFoodResultRow(
                            title: "Create \"\(trimmedQuickText)\"",
                            subtitle: "Local estimate, ready for review",
                            symbol: "text.badge.plus",
                            accessibilityIdentifier: "CreateFoodDraft-\(Self.slug(trimmedQuickText))",
                            action: createQuickTextDraft
                        )
                    }
                }
            }
        }
        .navigationTitle("Add Food")
        .mealMarkNavigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
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
        .sheet(isPresented: $isShowingBarcodeLookup) {
            NavigationStack {
                BarcodeLookupView(onDraftReady: onDraftReady)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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

    private var reusableRecentEntries: [FoodIntakeEntry] {
        hasSearchQuery ? [] : store.entries
    }

    private var reusablePersonalIngredients: [PersonalFoodIngredient] {
        hasSearchQuery ? [] : store.personalIngredients
    }

    private var shouldShowReusableResults: Bool {
        !hasSearchQuery && (!reusableRecentEntries.isEmpty || !reusablePersonalIngredients.isEmpty)
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
        hasSearchQuery && selectedScope == .all
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
            return "Try another word, or create a local draft from what you typed."
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
                        onScannerError: { message in
                            errorMessage = message
                        }
                    )
                    .id(scannerRestartID)
                    .frame(minHeight: 260)

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
        .mealMarkNavigationBarTitleDisplayModeInline()
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

    private func scanAgain() {
        errorMessage = nil
        detectedBarcode = nil
        scannerRestartID = UUID()
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
        .mealMarkGlassSurface(cornerRadius: 16, isInteractive: true)
    }
}

private struct AddFoodShortcutGrid: View {
    var canStartPhoto: Bool
    var onPhoto: () -> Void
    var onBarcode: () -> Void
    var onBuild: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            shortcutContainer {
                HStack(spacing: 10) {
                    AddFoodShortcutButton(
                        title: "Photo",
                        subtitle: canStartPhoto ? "Analyze" : "Unavailable",
                        symbol: "camera.fill",
                        accessibilityIdentifier: "AddFoodModePhotoButton",
                        isEnabled: canStartPhoto,
                        tint: .green,
                        action: onPhoto
                    )

                    AddFoodShortcutButton(
                        title: "Barcode",
                        subtitle: "Packaged",
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
                        tint: .orange,
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

private struct AnalysisNoFoodCard: View {
    var message: String
    var onRetry: () -> Void
    var onEnterManually: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("No food recognized", systemImage: "viewfinder.circle")
                .font(.headline)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("NoFoodTitle")

            Text(message.isEmpty ? "MealMark did not find visible food or a readable nutrition label in this photo." : message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("NoFoodMessage")

            Text("Nothing was saved. Take another photo, or add the food manually.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(role: .cancel, action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("DismissNoFoodButton")

                Spacer(minLength: 0)

                Button(action: onEnterManually) {
                    Label("Enter manually", systemImage: "text.badge.plus")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("EnterFoodManuallyButton")

                Button(action: onRetry) {
                    Label("Retake", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityIdentifier("RetryNoFoodPhotoButton")
            }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("NoFoodAnalysisCard")
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
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.primaryLabel)
                            .font(.title2.bold())
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
                    Spacer()
                    SourceBadge(
                        text: candidate.reviewBadgeText(trustStatus: trustStatus),
                        tint: trustStatus.reviewTint
                    )
                }

                HStack(spacing: 10) {
                    NutritionMetricView(title: "Calories", value: "\(candidate.nutrition.modeKcal)", unit: "kcal")
                    NutritionMetricView(title: "Protein", value: macroValue(candidate.macronutrients.proteinGrams), unit: "g")
                    NutritionMetricView(title: "Carbs", value: macroValue(candidate.macronutrients.carbohydrateGrams), unit: "g")
                    NutritionMetricView(title: "Fat", value: macroValue(candidate.macronutrients.fatGrams), unit: "g")
                }

                Label(candidate.confidence.label, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(trustStatus.reviewTint)

                PortionControlsView(
                    candidate: candidate,
                    gramsText: $portionGramsText,
                    onCommit: commitPortion
                )

                DraftActionBar(
                    canSave: store.canSaveDraft,
                    onDiscard: store.discardDraft,
                    onSave: {
                        commitPortion()
                        store.confirmDraft()
                    }
                )

                DraftExplanationSection(candidate: candidate, trustStatus: trustStatus)
            }
            .padding(18)
            .mealMarkGlassSurface(cornerRadius: 28, tint: trustStatus.reviewTint.opacity(0.055), isInteractive: false)
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
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.horizontal, 6)
        .mealMarkGlassSurface(cornerRadius: 18, tint: Color.secondary.opacity(0.055), isInteractive: false)
    }
}

private struct DraftExplanationSection: View {
    var candidate: FoodAnalysisCandidate
    var trustStatus: FoodTrustStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How MealMark read it", systemImage: "sparkle.magnifyingglass")
                .font(.headline)

            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("DraftRecognitionSummary")

            ForEach(Array(candidate.evidence.enumerated()), id: \.offset) { _, evidence in
                EvidenceSourceRow(evidence: evidence)
            }

            if !candidate.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assumptions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(candidate.assumptions) { assumption in
                        Label(assumption.label, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("DraftAssumption-\(assumption.id)")
                    }
                }
            }
        }
        .padding(12)
        .mealMarkGlassSurface(cornerRadius: 18, tint: Color.blue.opacity(0.055), isInteractive: false)
        .accessibilityIdentifier("DraftExplanationSection")
    }

    private var summary: String {
        let source = candidate.primarySourceLabel(trustStatus: trustStatus)
        switch candidate.confidence {
        case .high:
            return "\(source). The photo or lookup produced a specific match, but you still confirm the portion before saving."
        case .medium:
            return "\(source). MealMark found a plausible match and needs your portion review."
        case .low:
            return "\(source). This is a rough estimate; verify the food and grams before saving."
        }
    }
}

private struct EvidenceSourceRow: View {
    var evidence: ProviderEvidence

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(evidence.sourceLabel)
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("DraftEvidenceSourceLabel")
                Text("\(evidence.matchedName) • \(evidence.servingBasis)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("DraftEvidence-\(evidence.normalizedProvider)")
    }

    private var iconName: String {
        switch evidence.normalizedProvider {
        case "visible_nutrition_label":
            return "doc.text.viewfinder"
        case "barcode_provider", "open_food_facts", "open_food_facts_fixture":
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

private struct DraftActionBar: View {
    var canSave: Bool
    var onDiscard: () -> Void
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(role: .destructive, action: onDiscard) {
                Label("Discard", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityIdentifier("DiscardDraftButton")

            Button(action: onSave) {
                Label("Save", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!canSave)
            .accessibilityIdentifier("SaveToFoodWalletButton")
        }
    }
}

private struct PortionControlsView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @FocusState private var isGramsFieldFocused: Bool
    var candidate: FoodAnalysisCandidate
    @Binding var gramsText: String
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portion")
                .font(.headline)

            HStack(alignment: .center, spacing: 12) {
                portionButton(
                    symbol: "minus",
                    label: "Decrease portion",
                    identifier: "PortionDecreaseButton"
                ) {
                    update(to: max(1, candidate.portion.gramsMode - 25))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: gramsBinding)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 74, maxWidth: 108)
                        .focused($isGramsFieldFocused)
                        .accessibilityLabel("Portion grams")
                        .accessibilityIdentifier("PortionGramsField")
                        .onSubmit(onCommit)

                    Text("g")
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

                portionButton(
                    symbol: "plus",
                    label: "Increase portion",
                    identifier: "PortionIncreaseButton"
                ) {
                    update(to: candidate.portion.gramsMode + 25)
                }
            }

            Button {
                onCommit()
            } label: {
                Label("Apply grams", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("ApplyPortionGramsButton")
        }
        .padding(14)
        .mealMarkGlassSurface(cornerRadius: 22, tint: Color.secondary.opacity(0.055), isInteractive: false)
        .onChange(of: isGramsFieldFocused) { isFocused in
            if isFocused && gramsText == "\(candidate.portion.gramsMode)" {
                gramsText = ""
            } else if !isFocused {
                onCommit()
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

    private func portionButton(
        symbol: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .mealMarkGlassSurface(cornerRadius: 18, tint: Color.green.opacity(0.12), isInteractive: true)
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
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.sRGB, red: 0.98, green: 0.78, blue: 0.28, opacity: 1),
                            Color(.sRGB, red: 0.41, green: 0.78, blue: 0.37, opacity: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(-12))
                .shadow(color: .green.opacity(0.18), radius: 6, x: 0, y: 4)

            HStack(spacing: 5) {
                Circle()
                    .fill(.black.opacity(0.78))
                    .frame(width: 4, height: 4)
                Circle()
                    .fill(.black.opacity(0.78))
                    .frame(width: 4, height: 4)
            }
            .offset(y: -3)

            Capsule()
                .stroke(.black.opacity(0.72), lineWidth: 1.5)
                .frame(width: 13, height: 6)
                .offset(y: 7)

            HStack(spacing: 14) {
                Capsule()
                    .fill(.green.opacity(0.82))
                    .frame(width: 5, height: 12)
                    .rotationEffect(.degrees(isRunning ? 24 : -24))
                Capsule()
                    .fill(.green.opacity(0.82))
                    .frame(width: 5, height: 12)
                    .rotationEffect(.degrees(isRunning ? -24 : 24))
            }
            .offset(y: 17)
        }
        .offset(y: isRunning ? -2 : 2)
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: FoodWalletStore
    @State private var editingEntry: EditableMealEntry?
    @State private var isRefreshing = false

    var body: some View {
        ZStack(alignment: .top) {
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
                                SourceBadge(text: entry.trustStatus.label, tint: entry.trustStatus == .verified ? .green : .orange)
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

                    Section("Why this is in MealMark") {
                        LabeledContent("Source", value: entry.sourceClass.description)
                        LabeledContent("Trust", value: entry.trustStatus.label)
                        if let provenance = store.provenanceSnapshot(entryID: entry.entryID) {
                            LabeledContent("Primary evidence", value: provenance.primarySourceLabel)
                            ForEach(Array(provenance.evidence.enumerated()), id: \.offset) { _, evidence in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(evidence.sourceLabel)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(evidence.matchedName) • \(evidence.servingBasis)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityIdentifier("MealDetailEvidence-\(evidence.normalizedProvider)")
                            }
                        } else {
                            Text("This entry keeps confirmed nutrition values and trust labels. Detailed provider evidence is available for meals saved in the current session.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Record") {
                        LabeledContent("Date", value: entry.dateKey)
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
