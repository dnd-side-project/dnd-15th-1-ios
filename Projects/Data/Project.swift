import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .data,
    dependencies: [
        .domain,
        .coreNetwork,
        .coreSocialAuth,
        .coreStorage,
        .sharedLogger,
        .sharedUtils,
        .thirdPartyCore,
    ],
    includesTests: true
)
