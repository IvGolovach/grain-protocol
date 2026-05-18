import AppIntents
import Foundation

public enum FoodWalletDestination: String, AppEnum {
    case today
    case capture
    case history
    case wallet

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Food Wallet Destination")

    public static let caseDisplayRepresentations: [FoodWalletDestination: DisplayRepresentation] = [
        .today: "Today",
        .capture: "Capture",
        .history: "History",
        .wallet: "Wallet",
    ]
}

public struct OpenFoodWalletIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Food Wallet"
    public static let description = IntentDescription("Open Food Wallet to a useful destination.")
    public static let openAppWhenRun = true

    @Parameter(title: "Destination")
    public var destination: FoodWalletDestination

    public init() {
        destination = .today
    }

    public init(destination: FoodWalletDestination) {
        self.destination = destination
    }

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct StartFoodCaptureIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Food Capture"
    public static let description = IntentDescription("Open Food Wallet to capture or analyze food.")
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct QuickLogFoodIntent: AppIntent {
    public static let title: LocalizedStringResource = "Quick Log Food"
    public static let description = IntentDescription("Open Food Wallet with a quick food logging workflow.")
    public static let openAppWhenRun = true

    @Parameter(title: "Food")
    public var foodName: String

    public init() {
        foodName = "Apple"
    }

    public init(foodName: String) {
        self.foodName = foodName
    }

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct FoodWalletShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFoodCaptureIntent(),
            phrases: [
                "Analyze food in \(.applicationName)",
                "Log food in \(.applicationName)",
            ],
            shortTitle: "Analyze Food",
            systemImageName: "camera.viewfinder"
        )

        AppShortcut(
            intent: OpenFoodWalletIntent(destination: .today),
            phrases: [
                "Open today's food in \(.applicationName)",
                "Show my food wallet in \(.applicationName)",
            ],
            shortTitle: "Open Today",
            systemImageName: "list.bullet.rectangle"
        )

        AppShortcut(
            intent: QuickLogFoodIntent(),
            phrases: [
                "Quick log food in \(.applicationName)",
            ],
            shortTitle: "Quick Log",
            systemImageName: "plus.circle"
        )
    }
}
