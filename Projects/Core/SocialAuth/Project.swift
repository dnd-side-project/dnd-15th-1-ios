import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreSocialAuth,
    dependencies: [
        .sharedLogger,
        .thirdPartyCore,
    ]
)
