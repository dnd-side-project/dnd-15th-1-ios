import ProjectDescription

public enum ProjectFactory {
    /// 카탈로그 기반 framework 모듈.
    public static func framework(
        _ module: Module,
        dependencies: [TargetDependency] = [],
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = nil,
        product: Product = .staticLibrary,
        includesTests: Bool = false,
        testsDependencies: [TargetDependency] = []
    ) -> Project {
        framework(
            name: module.targetName,
            bundleIdSuffix: module.bundleIdSuffix,
            dependencies: dependencies,
            sources: sources,
            resources: resources,
            product: product,
            includesTests: includesTests,
            testsDependencies: testsDependencies
        )
    }

    /// 일반 framework/static library 모듈 생성.
    public static func framework(
        name: String,
        bundleIdSuffix: String,
        dependencies: [TargetDependency] = [],
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = nil,
        product: Product = .staticLibrary,
        schemes: [Scheme] = [],
        includesTests: Bool = false,
        testsDependencies: [TargetDependency] = []
    ) -> Project {
        let target = Target.target(
            name: name,
            destinations: ProjectEnvironment.destinations,
            product: product,
            bundleId: ProjectEnvironment.moduleBundleId(bundleIdSuffix),
            deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: ProjectSettings.framework()
        )

        var targets = [target]
        var projectSchemes = schemes

        if includesTests {
            let testsName = "\(name)Tests"
            let testsTarget = Target.target(
                name: testsName,
                destinations: ProjectEnvironment.destinations,
                product: .unitTests,
                bundleId: ProjectEnvironment.moduleBundleId("\(bundleIdSuffix).tests"),
                deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
                sources: ["Tests/**"],
                dependencies: [
                    .target(name: name),
                ] + testsDependencies,
                settings: ProjectSettings.unitTests()
            )
            targets.append(testsTarget)

            if projectSchemes.isEmpty {
                projectSchemes = [
                    .scheme(
                        name: name,
                        shared: true,
                        buildAction: .buildAction(targets: [.target(name)]),
                        testAction: .targets([.testableTarget(target: .target(testsName))])
                    )
                ]
            }
        }

        return Project(
            name: name,
            organizationName: ProjectEnvironment.organizationName,
            settings: ProjectSettings.project(),
            targets: targets,
            schemes: projectSchemes.isEmpty ? [makeBuildScheme(name: name)] : projectSchemes
        )
    }

    /// 외부 패키지 래퍼 모듈 (ThirdParty*).
    public static func thirdParty(
        _ module: Module,
        packages: [Package],
        productDependencies: [TargetDependency],
        product: Product = .staticLibrary
    ) -> Project {
        let target = Target.target(
            name: module.targetName,
            destinations: ProjectEnvironment.destinations,
            product: product,
            bundleId: ProjectEnvironment.moduleBundleId(module.bundleIdSuffix),
            deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
            sources: ["Sources/**"],
            dependencies: productDependencies,
            settings: ProjectSettings.framework()
        )

        return Project(
            name: module.targetName,
            organizationName: ProjectEnvironment.organizationName,
            packages: packages,
            settings: ProjectSettings.project(),
            targets: [target],
            schemes: [makeBuildScheme(name: module.targetName)]
        )
    }

    public static func feature(
        dependencies: [TargetDependency],
        testsDependencies: [TargetDependency] = []
    ) -> Project {
        let featureName = Module.feature.targetName

        let featureTarget = Target.target(
            name: featureName,
            destinations: ProjectEnvironment.destinations,
            product: .framework,
            bundleId: ProjectEnvironment.moduleBundleId(Module.feature.bundleIdSuffix),
            deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
            sources: ["Sources/**"],
            dependencies: dependencies,
            settings: ProjectSettings.framework()
        )

        let testsTarget = Target.target(
            name: "FeatureTests",
            destinations: ProjectEnvironment.destinations,
            product: .unitTests,
            bundleId: ProjectEnvironment.moduleBundleId("feature.tests"),
            deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: featureName),
            ] + testsDependencies,
            settings: ProjectSettings.unitTests()
        )

        return Project(
            name: featureName,
            organizationName: ProjectEnvironment.organizationName,
            settings: ProjectSettings.project(),
            targets: [featureTarget, testsTarget],
            schemes: [
                .scheme(
                    name: featureName,
                    shared: true,
                    buildAction: .buildAction(targets: [.target(featureName)]),
                    testAction: .targets(["FeatureTests"])
                )
            ]
        )
    }

    /// App 타겟 생성.
    ///
    /// `packages` 는 dynamic 바이너리를 품은 SPM 패키지를 앱 번들에 embed 하기 위한 통로다.
    /// 모듈 경계상 SDK 소유는 `ThirdParty*` 에 두고, App 은 embed 만 담당한다.
    public static func app(
        name: String = ProjectEnvironment.productName,
        dependencies: [TargetDependency],
        packages: [Package] = [],
        infoPlist: InfoPlist = DefaultInfoPlist.app,
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements = ["Resources/**"]
    ) -> Project {
        let target = Target.target(
            name: name,
            destinations: ProjectEnvironment.destinations,
            product: .app,
            bundleId: ProjectEnvironment.AppBundle.release,
            deploymentTargets: .iOS(ProjectEnvironment.deploymentTarget),
            infoPlist: infoPlist,
            sources: sources,
            resources: resources,
            entitlements: "Dulpick.entitlements",
            dependencies: dependencies,
            settings: ProjectSettings.app()
        )

        return Project(
            name: Module.app.targetName,
            organizationName: ProjectEnvironment.organizationName,
            packages: packages,
            settings: ProjectSettings.project(),
            targets: [target],
            schemes: [
                makeAppScheme(
                    name: "Dulpick-Debug",
                    targetName: name,
                    configuration: ProjectEnvironment.debugConfigName
                ),
                makeAppScheme(
                    name: "Dulpick",
                    targetName: name,
                    configuration: ProjectEnvironment.releaseConfigName
                ),
            ]
        )
    }

    private static func makeBuildScheme(name: String) -> Scheme {
        .scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(name)])
        )
    }

    private static func makeAppScheme(
        name: String,
        targetName: String,
        configuration: ConfigurationName
    ) -> Scheme {
        .scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(targetName)]),
            runAction: .runAction(
                configuration: configuration,
                executable: .target(targetName)
            ),
            archiveAction: .archiveAction(configuration: configuration),
            profileAction: .profileAction(
                configuration: configuration,
                executable: .target(targetName)
            ),
            analyzeAction: .analyzeAction(configuration: configuration)
        )
    }
}
