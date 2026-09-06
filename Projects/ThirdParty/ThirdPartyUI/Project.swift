import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdPartyUI,
    packages: [
        .package(url: "https://github.com/kean/Nuke", .exact("12.9.0")),
        .package(url: "https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM", .exact("2.12.17")),
        .package(url: "https://github.com/microsoft/clarity-apps", .exact("4.0.0")),
    ],
    productDependencies: [
        .package(product: "Nuke"),
        .package(product: "NukeUI"),
        .package(product: "KakaoMapsSDK-SPM"),
        .package(product: "Clarity"),
    ],
    product: .framework
)
