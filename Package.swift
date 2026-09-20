// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeminiVPN",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "GeminiVPNShared", targets: ["Shared"])
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Shared"
        )
    ]
)
