import XCTest

final class FoodWalletUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--grain-ui-test-photo-flow")
        app.launch()
    }

    func testAppleEstimateCanBeSavedAndViewed() throws {
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
}
