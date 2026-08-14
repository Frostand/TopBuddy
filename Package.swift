// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "TopBuddy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TopBuddy", targets: ["TopBuddy"])
    ],
    targets: [
        .executableTarget(
            name: "TopBuddy",
            path: "Sources/TopBuddy",
            exclude: ["Support/Info.plist", "Support/TopBuddy.entitlements"]
        ),
        .testTarget(
            name: "TopBuddyTests",
            dependencies: ["TopBuddy"],
            path: "Tests/TopBuddyTests"
        )
    ]
)
