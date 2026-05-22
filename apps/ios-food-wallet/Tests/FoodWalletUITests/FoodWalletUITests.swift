import XCTest

@MainActor
final class FoodWalletUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(
        arguments: [String] = ["--grain-ui-test-photo-flow"],
        resetFoodWalletStorage: Bool = true
    ) {
        app = XCUIApplication()
        app.launchArguments.append("--grain-ui-test-reset-personal-ingredients")
        if resetFoodWalletStorage {
            app.launchArguments.append("--grain-ui-test-reset-food-wallet-storage")
        }
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
    }

    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 4) -> Bool {
        if element.exists {
            return true
        }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }
        return element.exists
    }

    private func addFoodSearchField() -> XCUIElement {
        app.textFields["AddFoodSearchField"]
    }

    private func clearAndType(_ field: XCUIElement, text: String) {
        field.tap()
        let currentValue = field.value as? String ?? ""
        if !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        field.typeText(text)
    }

    private func currentDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func saveCurrentDraft() {
        XCTAssertTrue(scrollToElement(app.buttons["SaveToFoodWalletButton"]))
        app.buttons["SaveToFoodWalletButton"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    private func openBuildMealScreen() {
        let buildMealButton = app.buttons["AddFoodModeBuildMealButton"]
        XCTAssertTrue(buildMealButton.waitForExistence(timeout: 5))
        buildMealButton.tap()
        XCTAssertTrue(app.navigationBars["Build Meal"].waitForExistence(timeout: 5))
    }

    private func dismissBuildMealKeyboardIfNeeded() {
        let doneButton = app.buttons["BuildMealKeyboardDoneButton"]
        if doneButton.waitForExistence(timeout: 1) {
            doneButton.tap()
        }
    }

    private func dismissMealMarkKeyboardIfNeeded() {
        let keyboardButtonIdentifiers = [
            "UnknownFoodKeyboardDoneButton",
            "AddFoodKeyboardDoneButton",
            "BuildMealKeyboardDoneButton",
            "PortionKeyboardDoneButton",
            "SavedRecipeKeyboardDoneButton",
            "EditMealKeyboardDoneButton",
        ]
        for identifier in keyboardButtonIdentifiers {
            let doneButton = app.buttons[identifier]
            if doneButton.exists {
                doneButton.tap()
                return
            }
        }
        for identifier in keyboardButtonIdentifiers {
            let doneButton = app.buttons[identifier]
            if doneButton.waitForExistence(timeout: 0.2) {
                doneButton.tap()
                return
            }
        }
    }

    private func typePersonalIngredientValue(_ identifier: String, _ value: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(scrollToElement(field, maxSwipes: 6))
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(value)
        dismissMealMarkKeyboardIfNeeded()
    }

    func testAppleEstimateCanBeSavedAndViewed() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Fuji apple")
        XCTAssertTrue(app.staticTexts["DraftNutritionLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 170 g • 90-115 kcal")
        XCTAssertTrue(app.staticTexts["DraftMacronutrientsLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 0.5g • C 27g • F 0.3g")

        saveCurrentDraft()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["HistoryDayHeader-\(currentDateKey())"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MealRowLabel-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowLabel-Fuji apple"].label, "Fuji apple")
        XCTAssertTrue(app.staticTexts["MealRowTime-food-entry-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MealRowNutrition-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Fuji apple"].label, "170 g • 102 kcal")
        XCTAssertTrue(app.staticTexts["MealRowMacros-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowMacros-Fuji apple"].label, "P 0.5g • C 27g • F 0.3g")
        app.staticTexts["MealRowLabel-Fuji apple"].tap()
        XCTAssertTrue(app.navigationBars["Meal details"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MealDetailTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealDetailTitle"].label, "Fuji apple")
        XCTAssertTrue(app.staticTexts["MealDetailNutrition"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealDetailNutrition"].label, "170 g • 102 kcal")
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["MealDetailEvidence-curated_cache"]))

        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.navigationBars["Wallet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ConfirmedEntriesLabel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ConfirmedEntriesValue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["ConfirmedEntriesValue"].label, "1")
    }

    func testAnalysisProgressIsVisibleDuringDelayedPhotoEstimate() throws {
        launch(arguments: [
            "--grain-ui-test-delayed-photo-flow",
            "--grain-analysis-delay-ms",
            "5000"
        ])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        let loadingView = app.descendants(matching: .any)["AnalysisLoadingView"]
        XCTAssertTrue(loadingView.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(loadingView.frame.height, app.frame.height * 0.8)
        XCTAssertGreaterThan(loadingView.frame.width, app.frame.width * 0.8)
        XCTAssertTrue(app.staticTexts["AnalysisStatusLabel"].waitForExistence(timeout: 2))
        XCTAssertTrue([
            "Looking for food",
            "Estimating portion",
            "Checking nutrition ranges",
            "Preparing draft"
        ].contains(app.staticTexts["AnalysisStatusLabel"].label))
        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Fuji apple")
    }

    func testNoFoodPhotoShowsRecoveryActionsAndManualEntry() throws {
        launch(arguments: ["--grain-ui-test-no-food-photo-flow"])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NoFoodTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NoFoodMessage"].label.localizedCaseInsensitiveContains("no food"))
        XCTAssertFalse(app.staticTexts["DraftPrimaryLabel"].exists)
        XCTAssertFalse(app.buttons["SaveToFoodWalletButton"].exists)
        XCTAssertTrue(app.buttons["RetryNoFoodPhotoButton"].exists)
        XCTAssertTrue(app.buttons["EnterFoodManuallyButton"].exists)
        XCTAssertTrue(app.buttons["DismissNoFoodButton"].exists)

        app.buttons["EnterFoodManuallyButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["AddFoodSearchField"].waitForExistence(timeout: 5))
    }

    func testAddFoodHubCreatesTypedFoodDraftAndAdjustsPortion() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["AddFoodModeChooser"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["AddFoodModeBarcodeButton"].exists)
        XCTAssertFalse(app.buttons["AddFoodModeQuickAddButton"].exists)
        XCTAssertFalse(app.staticTexts["Suggestions"].exists)
        XCTAssertFalse(app.buttons["QuickSuggestion-apple"].exists)
        XCTAssertFalse(app.buttons["RepeatLastMealButton"].exists)
        XCTAssertFalse(app.buttons["CopyPreviousDayButton"].exists)
        XCTAssertFalse(app.buttons["VisibleLabelKombuchaButton"].exists)
        XCTAssertFalse(app.buttons["BarcodeKombuchaButton"].exists)
        XCTAssertFalse(app.buttons["Template-usual-breakfast"].exists)
        XCTAssertFalse(app.buttons["Recipe-tomato-cucumber-salad"].exists)
        XCTAssertFalse(app.textFields["MealTitleField"].exists)

        let searchText = app.textFields["AddFoodSearchField"]
        XCTAssertTrue(searchText.waitForExistence(timeout: 5))
        searchText.tap()
        searchText.typeText("apple")
        app.buttons["CreateTypedFoodDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Apple")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 100 g • 47-57 kcal")
        XCTAssertFalse(app.switches.matching(identifier: "Assumption-user-portion").firstMatch.exists)
        XCTAssertFalse(app.buttons["PortionHalfButton"].exists)
        XCTAssertFalse(app.buttons["ApplyPortionGramsButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["PortionUnitPicker"].waitForExistence(timeout: 5))

        let gramsField = app.textFields["PortionGramsField"]
        XCTAssertTrue(scrollToElement(gramsField))
        gramsField.tap()
        gramsField.typeText("150")
        XCTAssertTrue(app.buttons["PortionKeyboardDoneButton"].waitForExistence(timeout: 2))
        app.buttons["PortionKeyboardDoneButton"].tap()
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 150 g • 71-86 kcal")

        saveCurrentDraft()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-Apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Apple"].label, "150 g • 78 kcal")
    }

    func testAddFoodHubDoesNotInventNutritionForUnknownTypedFood() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))

        let searchText = app.textFields["AddFoodSearchField"]
        XCTAssertTrue(searchText.waitForExistence(timeout: 5))
        searchText.tap()
        searchText.typeText("JAANA")
        app.buttons["CreateTypedFoodDraftButton"].tap()

        XCTAssertTrue(app.buttons["SearchDeeperFoodButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UnknownFoodResolutionTitle"].exists)
        XCTAssertFalse(app.navigationBars["Review food"].exists)
        XCTAssertFalse(app.staticTexts["DraftPrimaryLabel"].exists)
        XCTAssertTrue(app.buttons["SearchDeeperFoodButton"].exists)
        XCTAssertTrue(app.buttons["EnterManualNutritionButton"].exists)
        XCTAssertTrue(app.buttons["UnknownFoodBarcodeButton"].exists)
        XCTAssertTrue(app.buttons["UnknownFoodPhotoLabelButton"].exists)

        app.buttons["EnterManualNutritionButton"].tap()
        XCTAssertTrue(app.navigationBars["Enter Nutrition"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PersonalIngredientNameLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["PersonalIngredientNameLabel"].label, "JAANA")

        typePersonalIngredientValue("PersonalIngredientServingGramsField", "30")
        typePersonalIngredientValue("PersonalIngredientCaloriesField", "200")
        typePersonalIngredientValue("PersonalIngredientProteinField", "5")
        typePersonalIngredientValue("PersonalIngredientCarbsField", "20")
        typePersonalIngredientValue("PersonalIngredientFatField", "8")
        typePersonalIngredientValue("PersonalIngredientFiberField", "2")
        XCTAssertTrue(scrollToElement(app.buttons["SavePersonalIngredientButton"]))
        app.buttons["SavePersonalIngredientButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "JAANA")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 30 g • 180-220 kcal")
    }

    func testAddFoodStartsWithCompactModeChooserAndNoDeadFixtureActions() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["AddFoodModeChooser"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["AddFoodPhotoCameraButton"].exists)
        XCTAssertTrue(app.buttons["AddFoodPhotoLibraryButton"].exists)
        XCTAssertTrue(app.buttons["AddFoodModeBarcodeButton"].exists)
        XCTAssertFalse(app.buttons["AddFoodModeQuickAddButton"].exists)
        XCTAssertTrue(app.buttons["AddFoodModeBuildMealButton"].exists)
        XCTAssertFalse(app.staticTexts["Suggestions"].exists)
        XCTAssertFalse(app.buttons["QuickSuggestion-2-eggs-and-toast"].exists)
        XCTAssertFalse(app.buttons["RepeatLastMealButton"].exists)
        XCTAssertFalse(app.buttons["CopyPreviousDayButton"].exists)
        XCTAssertFalse(app.buttons["AddFoodScope-all"].exists)
        XCTAssertFalse(app.textFields["MealTitleField"].exists)

        let searchField = addFoodSearchField()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(searchField.isHittable)

        searchField.tap()
        searchField.typeText("casein protein")
        XCTAssertFalse(app.otherElements["AddFoodModeChooser"].exists)
        XCTAssertTrue(app.staticTexts["AddFoodSearchModeHint"].waitForExistence(timeout: 5))
        let caseinResult = app.buttons["FoodSearchResult-casein-protein"]
        XCTAssertTrue(caseinResult.waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["AnalyzeFujiAppleButton"].exists)
        XCTAssertFalse(app.buttons["AnalyzeMushroomRisottoButton"].exists)
        XCTAssertFalse(app.buttons["VisibleLabelKombuchaButton"].exists)
        XCTAssertFalse(app.buttons["BarcodeKombuchaButton"].exists)

        if app.buttons["AddFoodKeyboardDoneButton"].waitForExistence(timeout: 1) {
            app.buttons["AddFoodKeyboardDoneButton"].tap()
        }
        caseinResult.tap()
        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Casein protein powder")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 30 g • 97-119 kcal")
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 24g • C 3g • F 0.9g")
    }

    func testAddFoodBarcodeManualFallbackCreatesDraft() throws {
        launch(arguments: ["--grain-ui-test-barcode-flow"])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        app.buttons["AddFoodModeBarcodeButton"].tap()

        XCTAssertTrue(app.navigationBars["Scan code"].waitForExistence(timeout: 5))
        let barcodeField = app.textFields["BarcodeManualEntryField"]
        XCTAssertTrue(barcodeField.waitForExistence(timeout: 5))
        barcodeField.tap()
        barcodeField.typeText("012345678905")
        XCTAssertTrue(app.buttons["BarcodeKeyboardSearchButton"].waitForExistence(timeout: 2))
        app.buttons["BarcodeKeyboardSearchButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Ginger lemon kombucha")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 473 g • 80 kcal")
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 0g • C 19.9g • F 0g")
        XCTAssertFalse(app.switches.matching(identifier: "Assumption-barcode-match").firstMatch.exists)
    }

    func testAddFoodHubBuildsMealFromIngredients() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        openBuildMealScreen()

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Breakfast")

        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("eggs")
        XCTAssertTrue(app.buttons["IngredientUnitButton-0"].waitForExistence(timeout: 5))
        app.textFields["IngredientGramsField-0"].tap()
        app.textFields["IngredientGramsField-0"].typeText("100")

        app.textFields["IngredientNameField-1"].tap()
        app.textFields["IngredientNameField-1"].typeText("toast")
        app.textFields["IngredientGramsField-1"].tap()
        app.textFields["IngredientGramsField-1"].typeText("40")

        app.buttons["AddIngredientRowButton"].tap()
        app.textFields["IngredientNameField-2"].tap()
        app.textFields["IngredientNameField-2"].typeText("butter")
        app.textFields["IngredientGramsField-2"].tap()
        app.textFields["IngredientGramsField-2"].typeText("10")

        dismissBuildMealKeyboardIfNeeded()
        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Breakfast")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 150 g • 289-353 kcal")

        saveCurrentDraft()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-Breakfast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Breakfast"].label, "150 g • 321 kcal")
        XCTAssertTrue(app.staticTexts.matching(identifier: "MealRowTime-food-entry-1").firstMatch.waitForExistence(timeout: 5))

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.buttons["SavedRecipe-recipe-breakfast"]))
        app.buttons["SavedRecipe-recipe-breakfast"].tap()
        XCTAssertTrue(app.staticTexts["SavedMealDetailTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["SavedMealDetailTitle"].label, "Breakfast")
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["SavedMealQRCode"]))
        XCTAssertTrue(scrollToElement(app.buttons["LogSavedMealButton"]))
        XCTAssertTrue(scrollToElement(app.buttons["DeleteSavedMealButton"]))
        app.buttons["DeleteSavedMealButton"].tap()
        XCTAssertTrue(app.buttons["Keep recipe"].waitForExistence(timeout: 5))
        app.buttons["Keep recipe"].tap()
    }

    func testBuildMealIngredientSuggestionsFillMilkVariant() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        openBuildMealScreen()

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Cereal")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("mil")

        XCTAssertTrue(app.buttons["IngredientSuggestion-0-whole-milk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IngredientSuggestion-0-2-milk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IngredientSuggestion-0-skim-milk"].waitForExistence(timeout: 5))
        app.buttons["IngredientSuggestion-0-2-milk"].tap()

        XCTAssertEqual(app.textFields["IngredientNameField-0"].value as? String, "2% milk")
        XCTAssertEqual(app.textFields["IngredientGramsField-0"].value as? String, "100")
    }

    func testBuildMealIngredientSuggestionsShowCommonProteinVariants() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        openBuildMealScreen()

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Egg plate")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("egg")

        XCTAssertTrue(app.buttons["IngredientSuggestion-0-whole-egg"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IngredientSuggestion-0-egg-whites"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IngredientSuggestion-0-boiled-egg"].waitForExistence(timeout: 5))
        app.buttons["IngredientSuggestion-0-egg-whites"].tap()

        XCTAssertEqual(app.textFields["IngredientNameField-0"].value as? String, "Egg whites")
        XCTAssertEqual(app.textFields["IngredientGramsField-0"].value as? String, "100")
    }

    func testAddFoodHubResolvesCaseinProteinIngredient() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        openBuildMealScreen()

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Casein shake")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("casein protein")
        app.textFields["IngredientGramsField-0"].tap()
        app.textFields["IngredientGramsField-0"].typeText("30")
        dismissBuildMealKeyboardIfNeeded()
        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Casein shake")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 30 g • 97-119 kcal")
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 24g • C 3g • F 0.9g")
    }

    func testAddFoodHubCanSaveUnknownIngredientFromLabel() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        openBuildMealScreen()

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Granola bowl")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("house granola")
        app.textFields["IngredientGramsField-0"].tap()
        app.textFields["IngredientGramsField-0"].typeText("40")
        dismissBuildMealKeyboardIfNeeded()
        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.staticTexts["PersonalIngredientNameLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["PersonalIngredientNameLabel"].label, "house granola")

        typePersonalIngredientValue("PersonalIngredientServingGramsField", "40")
        typePersonalIngredientValue("PersonalIngredientCaloriesField", "180")
        typePersonalIngredientValue("PersonalIngredientProteinField", "5")
        typePersonalIngredientValue("PersonalIngredientCarbsField", "24")
        typePersonalIngredientValue("PersonalIngredientFatField", "7")
        typePersonalIngredientValue("PersonalIngredientFiberField", "3")
        app.buttons["SavePersonalIngredientButton"].tap()

        XCTAssertTrue(app.navigationBars["Review food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Granola bowl")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 40 g • 162-198 kcal")
    }

    func testCaptureScreenDoesNotExposeSampleAnalysisButtons() throws {
        launch(arguments: [])

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Capture"].exists)
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["AnalyzeFujiAppleButton"].exists)
        XCTAssertFalse(app.buttons["AnalyzeMushroomRisottoButton"].exists)
    }

    func testWalletOffersSafeExportsAfterSavingEntry() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        saveCurrentDraft()

        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.navigationBars["Wallet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportPortableJSONButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportCSVButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportGrainBundleButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["ExportPrivacyLabel"]))
    }

    func testConfirmedEntryPersistsAcrossRelaunch() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        saveCurrentDraft()
        app.terminate()

        launch(resetFoodWalletStorage: false)

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Fuji apple"].label, "170 g • 102 kcal")
    }

    func testConfirmedEntryCanBeEditedFromSwipeAction() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        saveCurrentDraft()

        app.tabBars.buttons["History"].tap()
        let rowLabel = app.staticTexts["MealRowLabel-Fuji apple"]
        XCTAssertTrue(rowLabel.waitForExistence(timeout: 5))
        rowLabel.swipeLeft()
        XCTAssertTrue(app.buttons["EditMealButton-food-entry-1"].waitForExistence(timeout: 5))
        app.buttons["EditMealButton-food-entry-1"].tap()

        let gramsField = app.textFields["EditMealGramsField"]
        XCTAssertTrue(gramsField.waitForExistence(timeout: 5))
        clearAndType(gramsField, text: "200")
        app.buttons["SaveEditedMealButton"].tap()

        XCTAssertTrue(app.staticTexts["MealRowNutrition-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Fuji apple"].label, "200 g • 120 kcal")
    }

    func testConfirmedEntryCanBeDeletedFromSwipeAction() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        saveCurrentDraft()

        app.tabBars.buttons["History"].tap()
        let rowLabel = app.staticTexts["MealRowLabel-Fuji apple"]
        XCTAssertTrue(rowLabel.waitForExistence(timeout: 5))
        rowLabel.swipeLeft()
        XCTAssertTrue(app.buttons["DeleteMealButton-food-entry-1"].waitForExistence(timeout: 5))
        app.buttons["DeleteMealButton-food-entry-1"].tap()

        XCTAssertTrue(app.staticTexts["History is empty"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.staticTexts["ConfirmedEntriesValue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["ConfirmedEntriesValue"].label, "0")
    }

    func testRestorePreviewDoesNotMutateUntilApplied() throws {
        launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        saveCurrentDraft()

        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.staticTexts["ConfirmedEntriesValue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["ConfirmedEntriesValue"].label, "1")
        XCTAssertTrue(scrollToElement(app.buttons["PreviewLatestBackupButton"]))
        app.buttons["PreviewLatestBackupButton"].tap()

        XCTAssertTrue(app.staticTexts["RestorePreviewSummary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["RestorePreviewSummary"].label, "1 entry in bundle • 0 new • 1 already saved")
        XCTAssertFalse(app.buttons["ApplyRestoreButton"].isEnabled)
    }
}
