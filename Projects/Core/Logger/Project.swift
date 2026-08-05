import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreLogger,
    dependencies: [
        .sharedUtils,
        .thirdPartyCore,
    ]
)
