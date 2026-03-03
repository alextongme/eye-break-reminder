// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeBreak",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "eye_break_ui",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios"),
            ],
            path: "scripts/Sources",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
