import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreKakaoMap,
    dependencies: [
        .sharedDesignSystem,
        .sharedUtils,
        .sharedLogger,
        .thirdPartyUI,
    ],
    product: .framework,
    includesTests: true,
    testsDependencies: [
        .sharedUtils,
        .thirdPartyUI,
    ]
)
