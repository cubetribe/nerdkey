// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NerdKeyKit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "NerdKeyKit", targets: ["NerdKeyKit"]),
        .executable(name: "nerdkey-cli", targets: ["nerdkey-cli"]),
    ],
    dependencies: [
        // swift-crypto provides Crypto module on Linux (and re-exports CryptoKit compat on Apple)
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "NerdKeyKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/NerdKeyKit"
        ),
        .executableTarget(
            name: "nerdkey-cli",
            dependencies: ["NerdKeyKit"],
            path: "Sources/nerdkey-cli"
        ),
    ]
)
