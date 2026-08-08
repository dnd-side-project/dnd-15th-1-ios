import ProjectDescription
import ProjectDescriptionHelpers

let project = ProjectFactory.app(
    dependencies: [
        .feature,
        .data,
        .domain,
        .coreNetwork,
        .coreSocialAuth,
        .coreStorage,
        .sharedLogger,
        .sharedUtils,
        .sharedDesignSystem,
        .thirdParty,
        .thirdPartyUI,
        .thirdPartyCore,
    ]
)
