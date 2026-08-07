import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.thirdParty(
    .thirdPartyCore,
    packages: [
        .package(url: "https://github.com/Alamofire/Alamofire", .exact("5.12.0")),
        .package(url: "https://github.com/kakao/kakao-ios-sdk", .exact("2.28.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .exact("9.2.0")),
    ],
    productDependencies: [
        .package(product: "Alamofire"),
        .package(product: "KakaoSDKCommon"),
        .package(product: "KakaoSDKAuth"),
        .package(product: "KakaoSDKUser"),
        .package(product: "GoogleSignIn"),
    ]
)
