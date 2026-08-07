import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .data,
    dependencies: [
        .domain,
        .coreNetwork,
        .coreStorage,
        .sharedLogger,
        .sharedUtils,
    ]
)
