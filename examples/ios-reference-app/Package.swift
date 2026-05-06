// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GrainIOSReferenceApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrainIOSReferenceAppCore", targets: ["GrainIOSReferenceAppCore"]),
        .executable(name: "GrainIOSReferenceApp", targets: ["GrainIOSReferenceApp"]),
        .executable(name: "GrainIOSReferenceAppSmoke", targets: ["GrainIOSReferenceAppSmoke"]),
    ],
    dependencies: [
        .package(name: "GrainClient", path: "../../sdk/swift"),
        .package(name: "GrainIOSScannerExample", path: "../ios-scanner"),
    ],
    targets: [
        .target(
            name: "GrainIOSReferenceAppCore",
            dependencies: [
                .product(name: "GrainClientIOSAdapters", package: "GrainClient"),
                .product(name: "GrainIOSScanner", package: "GrainIOSScannerExample"),
            ],
            path: "Sources/GrainIOSReferenceAppCore",
            resources: [
                .copy("Resources"),
            ]
        ),
        .executableTarget(
            name: "GrainIOSReferenceApp",
            dependencies: ["GrainIOSReferenceAppCore"],
            path: "Sources/GrainIOSReferenceApp"
        ),
        .executableTarget(
            name: "GrainIOSReferenceAppSmoke",
            dependencies: [
                "GrainIOSReferenceAppCore",
                .product(name: "GrainIOSScanner", package: "GrainIOSScannerExample"),
            ],
            path: "Sources/GrainIOSReferenceAppSmoke"
        ),
    ]
)
