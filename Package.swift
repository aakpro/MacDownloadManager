// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDownloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacDownloaderCore",
            targets: ["MacDownloaderCore"]
        ),
        .executable(
            name: "MacDownloader",
            targets: ["MacDownloaderApp"]
        )
    ],
    targets: [
        .target(
            name: "MacDownloaderCore",
            dependencies: [],
            path: "Sources/MacDownloaderCore"
        ),
        .executableTarget(
            name: "MacDownloaderApp",
            dependencies: ["MacDownloaderCore"],
            path: "Sources/MacDownloaderApp"
        ),
        .testTarget(
            name: "MacDownloaderTests",
            dependencies: ["MacDownloaderCore"],
            path: "Tests/MacDownloaderTests"
        )
    ]
)
