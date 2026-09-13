import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.framework(
    .coreImageCache,
    dependencies: [
        .sharedDesignSystem,
        .thirdPartyUI,
    ],
    product: .framework,
    includesTests: true,
    testsDependencies: [
        .thirdPartyUI,
    ]
)
