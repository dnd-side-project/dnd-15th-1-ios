import ProjectDescription

public enum DefaultInfoPlist {
    public static let app: InfoPlist = .extendingDefault(with: [
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "CFBundleShortVersionString": .string(ProjectEnvironment.appVersion),
        "CFBundleVersion": .string(ProjectEnvironment.appBuildNumber),

        "API_BASE_URL": "$(API_BASE_URL)",

        "UIAppFonts": [
            "Pretendard-Regular.otf",
            "Pretendard-Medium.otf",
            "Pretendard-SemiBold.otf",
            "Pretendard-Bold.otf",
        ],

        "UILaunchStoryboardName": "LaunchScreen",
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
        ],
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [:],
        ],

        // 딥링크용 커스텀 스킴: dulpick://home
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
