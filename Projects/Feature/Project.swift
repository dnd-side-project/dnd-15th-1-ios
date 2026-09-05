import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.feature(
    dependencies: [
        .domain,
        .sharedUtils,
        .sharedDesignSystem,
        .sharedLogger,
        .thirdParty,
        .coreImageCache,
        .coreKakaoMap,
        .coreUserAnalytics,
    ],
    testsDependencies: [
        .domain,
        .sharedDesignSystem,
        .sharedUtils,
        .thirdParty,
        .coreKakaoMap,
    ]
)
