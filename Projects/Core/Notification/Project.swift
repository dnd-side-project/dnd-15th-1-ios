import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreNotification,
    dependencies: [
        .sharedLogger,
        .thirdPartyCore,
    ],
    includesTests: true
)
