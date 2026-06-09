// swift-tools-version: 6.0

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repoRoot = packageDirectory.deletingLastPathComponent().deletingLastPathComponent().path
let rustDebugLibraryPath = "\(repoRoot)/core/rust/target/debug"
let buildEnvironment = ProcessInfo.processInfo.environment
let rustIOSDebugStaticLibraryPath: String = {
    if let override = buildEnvironment["GRAIN_CLIENT_CORE_IOS_STATIC_LIBRARY_PATH"] {
        return override
    }

    let platformHint = [
        buildEnvironment["PLATFORM_NAME"],
        buildEnvironment["EFFECTIVE_PLATFORM_NAME"],
        buildEnvironment["SDKROOT"],
    ]
    .compactMap { $0 }
    .joined(separator: " ")

    if platformHint.localizedCaseInsensitiveContains("simulator") {
        let currentArch = buildEnvironment["CURRENT_ARCH"]?.lowercased()
        let archs = buildEnvironment["ARCHS"]?.lowercased()
        let simulatorRustTarget: String
        if currentArch?.contains("x86_64") == true {
            simulatorRustTarget = "x86_64-apple-ios"
        } else if currentArch?.contains("arm64") == true || currentArch?.contains("aarch64") == true {
            simulatorRustTarget = "aarch64-apple-ios-sim"
        } else if archs?.contains("x86_64") == true
            && archs?.contains("arm64") != true
            && archs?.contains("aarch64") != true {
            simulatorRustTarget = "x86_64-apple-ios"
        } else {
            simulatorRustTarget = "aarch64-apple-ios-sim"
        }

        return buildEnvironment["GRAIN_CLIENT_CORE_IOS_SIMULATOR_STATIC_LIBRARY_PATH"]
            ?? "\(repoRoot)/core/rust/target/\(simulatorRustTarget)/debug/libgrain_client_core.a"
    }

    return buildEnvironment["GRAIN_CLIENT_CORE_IOS_DEVICE_STATIC_LIBRARY_PATH"]
        ?? "\(repoRoot)/core/rust/target/aarch64-apple-ios/debug/libgrain_client_core.a"
}()

let package = Package(
    name: "GrainClient",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrainClient", targets: ["GrainClient"]),
        .library(name: "GrainClientIOSAdapters", targets: ["GrainClientIOSAdapters"]),
        .library(name: "GrainFoodWallet", targets: ["GrainFoodWallet"]),
        .executable(name: "GrainClientFixtureRunner", targets: ["GrainClientFixtureRunner"]),
        .executable(name: "GrainClientIOSAdaptersSmoke", targets: ["GrainClientIOSAdaptersSmoke"]),
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
                    "-Xlinker", "-force_load",
                    "-Xlinker", rustIOSDebugStaticLibraryPath,
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
    ]
)
