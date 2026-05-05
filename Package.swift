// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexAppServerKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "CodexAppServerKit",
            targets: ["CodexAppServerKit"]
        )
    ],
    targets: [
        .target(
            name: "CodexAppServerKit"
        ),
        .testTarget(
            name: "CodexAppServerKitTests",
            dependencies: ["CodexAppServerKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
