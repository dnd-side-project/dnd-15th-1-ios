import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreStorage,
    dependencies: [
        .sharedUtils,
        .sharedLogger,
        .thirdPartyCore,
    ]
)
