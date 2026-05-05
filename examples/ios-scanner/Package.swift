// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GrainIOSScannerExample",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrainIOSScanner", targets: ["GrainIOSScanner"]),
        .executable(name: "GrainIOSScannerSmoke", targets: ["GrainIOSScannerSmoke"]),
    ],
    dependencies: [
        .package(name: "GrainClient", path: "../../sdk/swift"),
    ],
    targets: [
        .target(
            name: "GrainIOSScanner",
            dependencies: [
                .product(name: "GrainClient", package: "GrainClient"),
                .product(name: "GrainClientIOSAdapters", package: "GrainClient"),
            ],
            path: "Sources/GrainIOSScanner"
        ),
        .executableTarget(
            name: "GrainIOSScannerSmoke",
            dependencies: ["GrainIOSScanner"],
            path: "Sources/GrainIOSScannerSmoke"
        ),
    ]
)
