// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUsageTracker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AIUsageTracker",
            targets: ["AIUsageTracker"]
        ),
    ],
    dependencies: [
        // Add external dependencies here if needed
    ],
    targets: [
        .target(
            name: "AIUsageTracker",
            dependencies: [],
            path: "AIUsageTracker",
            exclude: ["Widget"]
        ),
    ]
)

