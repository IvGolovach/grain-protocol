import XCTest

@MainActor
final class FoodWalletUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(arguments: [String] = ["--grain-ui-test-photo-flow"]) {
        app = XCUIApplication()
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
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
}
