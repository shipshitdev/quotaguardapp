// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuotaGuardCLI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "quotaguard", targets: ["QuotaGuardCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "QuotaGuardCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        )
    ]
)
