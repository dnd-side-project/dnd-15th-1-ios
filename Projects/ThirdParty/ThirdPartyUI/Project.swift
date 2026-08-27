import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdPartyUI,
    packages: [
        .package(url: "https://github.com/kean/Nuke", .exact("12.9.0")),
        .package(url: "https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM", .exact("2.12.17")),
    ],
    productDependencies: [
        .package(product: "Nuke"),
        .package(product: "NukeUI"),
        .package(product: "KakaoMapsSDK-SPM"),
    ],
    product: .framework
)
