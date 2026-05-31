// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LivePhotoMaker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LivePhotoMaker", targets: ["LivePhotoMaker"])
    ],
    targets: [
        .executableTarget(
            name: "LivePhotoMaker",
            path: "Sources/LivePhotoMaker"
        )
    ]
)
