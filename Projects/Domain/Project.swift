import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .domain,
    dependencies: [
        .sharedUtils,
        .thirdParty,
    ],
    product: .framework,
    includesTests: true,
    testsDependencies: [
        .sharedUtils,
    ]
)
