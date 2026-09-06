import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.app(
    dependencies: [
        .feature,
        .data,
        .domain,
        .coreNotification,
        .coreNetwork,
        .coreSocialAuth,
        .coreStorage,
        .coreImageCache,
        .coreKakaoMap,
        .coreUserAnalytics,
        .sharedLogger,
        .sharedUtils,
        .sharedDesignSystem,
        .thirdParty,
        .thirdPartyUI,
        .thirdPartyCore,
        // KakaoMapsSDK 는 dynamic xcframework 라 앱 번들에 embed 돼야 한다.
        // SDK 사용 표면은 ThirdPartyUI 가 계속 소유하고, 여기서는 embed 만 한다
        .package(product: "KakaoMapsSDK-SPM"),
        // Clarity 는 dynamic xcframework 라 앱 번들에 embed 돼야 한다.
        // SDK 사용 표면은 ThirdPartyUI 가 계속 소유하고, 여기서는 embed 만 한다
        .package(product: "Clarity"),
    ],
    packages: [
        .package(url: "https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM", .exact("2.12.17")),
        .package(url: "https://github.com/microsoft/clarity-apps", .exact("4.0.0")),
    ]
)
