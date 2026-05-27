// swift-tools-version: 6.0

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repoRoot = packageDirectory.deletingLastPathComponent().deletingLastPathComponent().path
let rustDebugLibraryPath = "\(repoRoot)/core/rust/target/debug"
let rustIOSDebugStaticLibraryPath = ProcessInfo.processInfo.environment["GRAIN_CLIENT_CORE_IOS_STATIC_LIBRARY_PATH"]
    ?? "\(repoRoot)/core/rust/target/aarch64-apple-ios/debug/libgrain_client_core.a"

let package = Package(
    name: "GrainClient",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrainClient", targets: ["GrainClient"]),
        .library(name: "GrainClientIOSAdapters", targets: ["GrainClientIOSAdapters"]),
        .library(name: "GrainFoodGraph", targets: ["GrainFoodGraph"]),
        .library(name: "GrainFoodWallet", targets: ["GrainFoodWallet"]),
        .executable(name: "GrainClientFixtureRunner", targets: ["GrainClientFixtureRunner"]),
        .executable(name: "GrainClientIOSAdaptersSmoke", targets: ["GrainClientIOSAdaptersSmoke"]),
        .executable(name: "GrainFoodGraphSmoke", targets: ["GrainFoodGraphSmoke"]),
        .executable(name: "GrainFoodWalletSmoke", targets: ["GrainFoodWalletSmoke"]),
    ],
    targets: [
        .target(
            name: "grain_client_coreFFI",
            path: "Sources/grain_client_coreFFI",
            publicHeadersPath: "include"
        ),
        .target(
            name: "GrainClientFFI",
            dependencies: ["grain_client_coreFFI"],
            path: "Sources/GrainClientFFI",
            linkerSettings: [
                .unsafeFlags([
                    "-L", rustDebugLibraryPath,
                    "-lgrain_client_core",
                    "-Xlinker", "-rpath",
                    "-Xlinker", rustDebugLibraryPath,
                ], .when(platforms: [.macOS])),
                .unsafeFlags([
                    rustIOSDebugStaticLibraryPath,
                ], .when(platforms: [.iOS])),
            ]
        ),
        .target(
            name: "GrainClient",
            dependencies: ["GrainClientFFI"],
            path: "Sources/GrainClient"
        ),
        .target(
            name: "GrainClientIOSAdapters",
            dependencies: ["GrainClient"],
            path: "Sources/GrainClientIOSAdapters",
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.iOS, .macOS])),
            ]
        ),
        .target(
            name: "GrainFoodWallet",
            dependencies: [],
            path: "Sources/GrainFoodWallet"
        ),
        .target(
            name: "GrainFoodGraph",
            dependencies: [],
            path: "Sources/GrainFoodGraph",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "GrainClientFixtureRunner",
            dependencies: ["GrainClient"],
            path: "Sources/GrainClientFixtureRunner"
        ),
        .executableTarget(
            name: "GrainClientIOSAdaptersSmoke",
            dependencies: ["GrainClient", "GrainClientIOSAdapters"],
            path: "Sources/GrainClientIOSAdaptersSmoke"
        ),
        .executableTarget(
            name: "GrainFoodWalletSmoke",
            dependencies: ["GrainFoodWallet"],
            path: "Sources/GrainFoodWalletSmoke"
        ),
        .executableTarget(
            name: "GrainFoodGraphSmoke",
            dependencies: ["GrainFoodGraph"],
            path: "Sources/GrainFoodGraphSmoke"
        ),
    ]
)
