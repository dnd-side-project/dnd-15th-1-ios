import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.feature(
    dependencies: [
        .domain,
        .sharedUtils,
        .sharedDesignSystem,
        .thirdParty,
        .thirdPartyUI,
    ],
    testsDependencies: [
        .domain,
        .thirdParty,
    ]
)
