// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OfflineVoiceMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OfflineVoiceMac", targets: ["OfflineVoiceMac"])
    ],
    targets: [
        .executableTarget(
            name: "OfflineVoiceMac",
            path: "Sources/OfflineVoiceMac"
        )
    ]
)
