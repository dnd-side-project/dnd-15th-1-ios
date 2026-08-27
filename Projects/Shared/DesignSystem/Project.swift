import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .sharedDesignSystem,
    dependencies: [
        .sharedUtils,
    ],
    resources: ["Resources/**"],
    product: .framework
)
