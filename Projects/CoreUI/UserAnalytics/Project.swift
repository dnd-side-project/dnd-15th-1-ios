import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreUserAnalytics,
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
    ]
)
