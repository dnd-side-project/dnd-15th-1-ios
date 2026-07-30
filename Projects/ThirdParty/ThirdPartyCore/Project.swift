import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdPartyCore,
    packages: [
        .package(url: "https://github.com/Alamofire/Alamofire", .exact("5.12.0")),
    ],
    productDependencies: [
        .package(product: "Alamofire"),
    ]
)
