// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SamsungTizen",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SamsungTizen", targets: ["SamsungTizen"])
    ],
    targets: [
        .executableTarget(
            name: "SamsungTizen",
            resources: [.copy("AppAssets"), .copy("app-catalog.json")]
        )
    ]
)
