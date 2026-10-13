// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "TizenMenubar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TizenMenubar", targets: ["TizenMenubar"])],
    targets: [
        .executableTarget(
            name: "TizenMenubar",
            resources: [.copy("AppAssets"), .copy("app-catalog.json")]
        )
    ]
)
