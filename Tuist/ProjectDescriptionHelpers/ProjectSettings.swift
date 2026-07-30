import ProjectDescription

public enum ProjectSettings {
    public static let base: SettingsDictionary = [
        "SWIFT_VERSION": .string(ProjectEnvironment.swiftVersion),
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "IPHONEOS_DEPLOYMENT_TARGET": .string(ProjectEnvironment.deploymentTarget),
        // Xcode recommended settings
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
    ]

    public static let debug: SettingsDictionary = [
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ONLY_ACTIVE_ARCH": "YES",
        "ENABLE_TESTABILITY": "YES",
    ]

    public static let release: SettingsDictionary = [
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ONLY_ACTIVE_ARCH": "NO",
        "ENABLE_TESTABILITY": "NO",
    ]

    public static func framework(extraBase: SettingsDictionary = [:]) -> Settings {
        .settings(
            base: base.merging(extraBase) { _, new in new },
            configurations: [
                .debug(name: ProjectEnvironment.debugConfigName, settings: debug),
                .release(name: ProjectEnvironment.releaseConfigName, settings: release),
            ]
        )
    }

    public static func unitTests() -> Settings {
        framework(extraBase: [
            "GENERATE_INFOPLIST_FILE": "YES",
        ])
    }

    public static func app() -> Settings {
        let debugSettings = debug.merging([
            "PRODUCT_BUNDLE_IDENTIFIER": .string(ProjectEnvironment.AppBundle.debug),
            "APP_DISPLAY_NAME": .string(ProjectEnvironment.displayName + " Dev"),
            "PRODUCT_NAME": .string(ProjectEnvironment.productName),
            "GENERATE_INFOPLIST_FILE": "NO",
            "TARGETED_DEVICE_FAMILY": "1",
        ]) { _, new in new }

        let releaseSettings = release.merging([
            "PRODUCT_BUNDLE_IDENTIFIER": .string(ProjectEnvironment.AppBundle.release),
            "APP_DISPLAY_NAME": .string(ProjectEnvironment.displayName),
            "PRODUCT_NAME": .string(ProjectEnvironment.productName),
            "GENERATE_INFOPLIST_FILE": "NO",
            "TARGETED_DEVICE_FAMILY": "1",
        ]) { _, new in new }

        return .settings(
            base: base,
            configurations: [
                .debug(
                    name: ProjectEnvironment.debugConfigName,
                    settings: debugSettings,
                    xcconfig: .relativeToRoot("Config/Debug.xcconfig")
                ),
                .release(
                    name: ProjectEnvironment.releaseConfigName,
                    settings: releaseSettings,
                    xcconfig: .relativeToRoot("Config/Release.xcconfig")
                ),
            ]
        )
    }
}
