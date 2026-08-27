import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.feature(
    dependencies: [
        .domain,
        .sharedUtils,
        .sharedDesignSystem,
        .sharedLogger,
        .thirdParty,
        .thirdPartyUI,
    ],
    testsDependencies: [
        .domain,
        .sharedDesignSystem,
        .thirdParty,
        .thirdPartyUI,
    ]
)
