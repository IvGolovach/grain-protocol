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

    func testAppleEstimateCanBeSavedAndViewed() throws {
        launch()

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Fuji apple")
        XCTAssertTrue(app.staticTexts["DraftNutritionLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 170 g • 90-115 kcal")
        XCTAssertTrue(app.staticTexts["DraftMacronutrientsLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 0.5g • C 27g • F 0.3g")

        app.buttons["SaveToFoodWalletButton"].tap()
        XCTAssertTrue(app.staticTexts["No active draft"].waitForExistence(timeout: 5))

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MealRowLabel-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowLabel-Fuji apple"].label, "Fuji apple")
        XCTAssertTrue(app.staticTexts["MealRowNutrition-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Fuji apple"].label, "170 g • 102 kcal")
        XCTAssertTrue(app.staticTexts["MealRowMacros-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowMacros-Fuji apple"].label, "P 0.5g • C 27g • F 0.3g")

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

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        let loadingView = app.descendants(matching: .any)["AnalysisLoadingView"]
        XCTAssertTrue(loadingView.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(loadingView.frame.height, app.frame.height * 0.8)
        XCTAssertGreaterThan(loadingView.frame.width, app.frame.width * 0.8)
        XCTAssertFalse(app.buttons["TakeMealPhotoButton"].isHittable)
        XCTAssertTrue(app.staticTexts["AnalysisStatusLabel"].waitForExistence(timeout: 2))
        XCTAssertTrue([
            "Looking for food",
            "Estimating portion",
            "Checking nutrition ranges",
            "Preparing draft"
        ].contains(app.staticTexts["AnalysisStatusLabel"].label))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Fuji apple")
    }

    func testAddFoodHubCreatesQuickTextDraftAndAdjustsPortion() throws {
        launch(arguments: [])

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["VisibleLabelKombuchaButton"].exists)
        XCTAssertFalse(app.buttons["BarcodeKombuchaButton"].exists)
        XCTAssertFalse(app.buttons["Template-usual-breakfast"].exists)
        XCTAssertFalse(app.buttons["Recipe-tomato-cucumber-salad"].exists)

        let quickText = app.textFields["QuickTextField"]
        XCTAssertTrue(quickText.waitForExistence(timeout: 5))
        quickText.tap()
        quickText.typeText("2 eggs and toast")
        app.buttons["CreateQuickDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "2 eggs and toast")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 220 g • 295-365 kcal")

        app.buttons["PortionHalfButton"].tap()
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 110 g • 148-183 kcal")

        app.buttons["SaveToFoodWalletButton"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-2 eggs and toast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-2 eggs and toast"].label, "110 g • 165 kcal")
    }

    func testAddFoodHubBuildsMealFromIngredients() throws {
        launch(arguments: [])

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Breakfast")

        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("eggs")
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

        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Breakfast")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 150 g • 289-353 kcal")

        app.buttons["SaveToFoodWalletButton"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-Breakfast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Breakfast"].label, "150 g • 321 kcal")
    }

    func testAddFoodHubResolvesCaseinProteinIngredient() throws {
        launch(arguments: [])

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Casein shake")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("casein protein")
        app.textFields["IngredientGramsField-0"].tap()
        app.textFields["IngredientGramsField-0"].typeText("30")
        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Casein shake")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 30 g • 97-119 kcal")
        XCTAssertEqual(app.staticTexts["DraftMacronutrientsLabel"].label, "P 24g • C 3g • F 0.9g")
    }

    func testAddFoodHubCanSaveUnknownIngredientFromLabel() throws {
        launch(arguments: [])

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))

        app.textFields["MealTitleField"].tap()
        app.textFields["MealTitleField"].typeText("Granola bowl")
        app.textFields["IngredientNameField-0"].tap()
        app.textFields["IngredientNameField-0"].typeText("house granola")
        app.textFields["IngredientGramsField-0"].tap()
        app.textFields["IngredientGramsField-0"].typeText("40")
        app.buttons["CreateIngredientMealDraftButton"].tap()

        XCTAssertTrue(app.staticTexts["IngredientBuilderError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PersonalIngredientNameLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["PersonalIngredientNameLabel"].label, "house granola")

        app.textFields["PersonalIngredientServingGramsField"].tap()
        app.textFields["PersonalIngredientServingGramsField"].typeText("40")
        app.textFields["PersonalIngredientCaloriesField"].tap()
        app.textFields["PersonalIngredientCaloriesField"].typeText("180")
        app.textFields["PersonalIngredientProteinField"].tap()
        app.textFields["PersonalIngredientProteinField"].typeText("5")
        app.textFields["PersonalIngredientCarbsField"].tap()
        app.textFields["PersonalIngredientCarbsField"].typeText("24")
        app.textFields["PersonalIngredientFatField"].tap()
        app.textFields["PersonalIngredientFatField"].typeText("7")
        app.textFields["PersonalIngredientFiberField"].tap()
        app.textFields["PersonalIngredientFiberField"].typeText("3")
        app.buttons["SavePersonalIngredientButton"].tap()

        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["DraftPrimaryLabel"].label, "Granola bowl")
        XCTAssertEqual(app.staticTexts["DraftNutritionLabel"].label, "about 40 g • 162-198 kcal")
    }

    func testCaptureScreenDoesNotExposeSampleAnalysisButtons() throws {
        launch(arguments: [])

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Capture"].tap()
        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["AnalyzeFujiAppleButton"].exists)
        XCTAssertFalse(app.buttons["AnalyzeMushroomRisottoButton"].exists)
    }

    func testWalletOffersSafeExportsAfterSavingEntry() throws {
        launch()

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        app.buttons["SaveToFoodWalletButton"].tap()

        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.navigationBars["Wallet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportPortableJSONButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportCSVButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ExportGrainBundleButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["ExportPrivacyLabel"]))
    }

    func testConfirmedEntryPersistsAcrossRelaunch() throws {
        launch()

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        app.buttons["SaveToFoodWalletButton"].tap()
        app.terminate()

        launch(resetFoodWalletStorage: false)

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["MealRowLabel-Fuji apple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["MealRowNutrition-Fuji apple"].label, "170 g • 102 kcal")
    }

    func testRestorePreviewDoesNotMutateUntilApplied() throws {
        launch()

        XCTAssertTrue(app.staticTexts["Food Wallet"].waitForExistence(timeout: 5))
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["DraftPrimaryLabel"].waitForExistence(timeout: 5))
        app.buttons["SaveToFoodWalletButton"].tap()

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
