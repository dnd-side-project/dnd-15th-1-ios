import ProjectDescription

public enum DefaultInfoPlist {
    public static let app: InfoPlist = .extendingDefault(with: [
        // Identity / version
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "CFBundleShortVersionString": .string(ProjectEnvironment.appVersion),
        "CFBundleVersion": .string(ProjectEnvironment.appBuildNumber),

        // Runtime config from Config/*.xcconfig
        "API_BASE_URL": "$(API_BASE_URL)",

        // Launch / orientation
        "UILaunchStoryboardName": "LaunchScreen",
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
        ],
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [:],
        ],

        // Custom URL scheme for deep links: dulpick://home
        "CFBundleURLTypes": [
            [
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleURLSchemes": ["dulpick"],
            ]
        ],
    ])

    public static let framework: InfoPlist = .default
    public static let test: InfoPlist = .default
}
