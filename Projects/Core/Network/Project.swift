import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreNetwork,
    dependencies: [
        .sharedUtils,
        .thirdPartyCore,
    ]
)
