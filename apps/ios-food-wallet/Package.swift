// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GrainFoodWalletApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "FoodWalletCore", targets: ["FoodWalletCore"]),
        .library(name: "FoodWalletAppIntents", targets: ["FoodWalletAppIntents"]),
        .executable(name: "FoodWalletApp", targets: ["FoodWalletApp"]),
        .executable(name: "FoodWalletCoreTests", targets: ["FoodWalletCoreTests"]),
        .executable(name: "FoodWalletSmoke", targets: ["FoodWalletSmoke"]),
    ],
    dependencies: [
        .package(name: "GrainClient", path: "../../sdk/swift"),
    ],
    targets: [
        .target(
            name: "FoodWalletCore",
            dependencies: [
                .product(name: "GrainFoodWallet", package: "GrainClient"),
            ],
            path: "Sources/FoodWalletCore"
        ),
        .target(
            name: "FoodWalletAppIntents",
            dependencies: ["FoodWalletCore"],
            path: "Sources/FoodWalletAppIntents"
        ),
        .executableTarget(
            name: "FoodWalletApp",
            dependencies: [
                "FoodWalletCore",
                "FoodWalletAppIntents",
            ],
            path: "Sources/FoodWalletApp"
        ),
        .executableTarget(
            name: "FoodWalletSmoke",
            dependencies: ["FoodWalletCore"],
            path: "Sources/FoodWalletSmoke"
        ),
        .executableTarget(
            name: "FoodWalletCoreTests",
            dependencies: ["FoodWalletCore"],
            path: "Tests/FoodWalletCoreTests"
        ),
    ]
)
