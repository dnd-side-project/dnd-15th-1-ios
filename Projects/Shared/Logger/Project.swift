import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .sharedLogger,
    dependencies: [
        .sharedUtils,
    ],
    product: .framework
)
