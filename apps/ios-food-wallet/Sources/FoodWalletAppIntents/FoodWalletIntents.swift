import AppIntents
import Foundation

public enum FoodWalletDestination: String, AppEnum {
    case today
    case history
    case wallet

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "MealMark Destination")

    public static let caseDisplayRepresentations: [FoodWalletDestination: DisplayRepresentation] = [
        .today: "Today",
        .history: "History",
        .wallet: "Wallet",
    ]
}

public struct FoodWalletAppIntentsPackage: AppIntentsPackage {}

public struct OpenFoodWalletIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open MealMark"
    public static let description = IntentDescription("Open MealMark to a useful destination.")
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

public struct FoodWalletShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenFoodWalletIntent(destination: .today),
            phrases: [
                "Open today's food in \(.applicationName)",
                "Show my meals in \(.applicationName)",
            ],
            shortTitle: "Open Today",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
