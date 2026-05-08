// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GrainIOSStarter",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrainIOSStarterCore", targets: ["GrainIOSStarterCore"]),
        .executable(name: "GrainIOSStarterApp", targets: ["GrainIOSStarterApp"]),
        .executable(name: "GrainIOSStarterSmoke", targets: ["GrainIOSStarterSmoke"]),
    ],
    dependencies: [
        .package(name: "GrainClient", path: "../../sdk/swift"),
        .package(name: "GrainIOSScannerExample", path: "../../examples/ios-scanner"),
    ],
    targets: [
        .target(
            name: "GrainIOSStarterCore",
            dependencies: [
                .product(name: "GrainClientIOSAdapters", package: "GrainClient"),
                .product(name: "GrainIOSScanner", package: "GrainIOSScannerExample"),
            ],
            path: "Sources/GrainIOSStarterCore",
            resources: [
                .copy("Resources"),
            ]
        ),
        .executableTarget(
            name: "GrainIOSStarterApp",
            dependencies: ["GrainIOSStarterCore"],
            path: "Sources/GrainIOSStarterApp"
        ),
        .executableTarget(
            name: "GrainIOSStarterSmoke",
            dependencies: [
                "GrainIOSStarterCore",
                .product(name: "GrainClientIOSAdapters", package: "GrainClient"),
                .product(name: "GrainIOSScanner", package: "GrainIOSScannerExample"),
            ],
            path: "Sources/GrainIOSStarterSmoke"
        ),
    ]
)
