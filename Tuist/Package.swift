// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DulpickTuistHelpers",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "ProjectDescriptionHelpers",
            targets: ["ProjectDescriptionHelpers"]
        )
    ],
    targets: [
        .target(
            name: "ProjectDescriptionHelpers",
            path: "ProjectDescriptionHelpers"
        )
    ]
)
