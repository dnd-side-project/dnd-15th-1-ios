import ProjectDescription
import ProjectDescriptionHelpers

/// `Dulpick-Tests` 스킴이 돌리는 테스트 타깃 목록.
/// 테스트 타깃을 추가하면 여기에도 넣는다. 넣지 않으면 CI 가 그 테스트를 돌리지 않는다.
private let testTargets: [TargetReference] = [
    .project(path: Module.feature.path, target: "FeatureTests"),
    .project(path: Module.data.path, target: "DataTests"),
    .project(path: Module.domain.path, target: "DomainTests"),
    .project(path: Module.coreNetwork.path, target: "CoreNetworkTests"),
    .project(path: Module.coreNotification.path, target: "CoreNotificationTests"),
    .project(path: Module.coreImageCache.path, target: "CoreImageCacheTests"),
    .project(path: Module.coreKakaoMap.path, target: "CoreKakaoMapTests"),
    .project(path: Module.coreUserAnalytics.path, target: "CoreUserAnalyticsTests"),
]

let workspace = Workspace(
    name: ProjectEnvironment.productName,
    projects: Module.workspaceProjectPaths,
    schemes: [
        .scheme(
            name: "Dulpick-Tests",
            shared: true,
            buildAction: .buildAction(targets: testTargets),
            testAction: .targets(testTargets.map { .testableTarget(target: $0) })
        )
    ]
)
