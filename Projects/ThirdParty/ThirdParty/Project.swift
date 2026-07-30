import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdParty,
    packages: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .exact("1.26.0")),
    ],
    productDependencies: [
        .package(product: "ComposableArchitecture"),
    ]
)
