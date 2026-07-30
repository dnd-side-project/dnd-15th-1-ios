import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.app(
    dependencies: [
        .feature,
        .data,
        .domain,
        .coreNetwork,
        .coreStorage,
        .coreLogger,
        .sharedUtils,
        .sharedDesignSystem,
        .thirdParty,
        .thirdPartyUI,
        .thirdPartyCore,
    ]
)
