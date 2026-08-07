import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdPartyUI,
    packages: [
        .package(url: "https://github.com/kean/Nuke", .exact("12.9.0")),
    ],
    productDependencies: [
        .package(product: "Nuke"),
        .package(product: "NukeUI"),
    ],
    product: .framework
)
