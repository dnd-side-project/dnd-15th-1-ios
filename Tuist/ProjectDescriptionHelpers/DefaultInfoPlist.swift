import ProjectDescription

public enum DefaultInfoPlist {
    public static let app: InfoPlist = .extendingDefault(with: [
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "CFBundleShortVersionString": .string(ProjectEnvironment.appVersion),
        "CFBundleVersion": .string(ProjectEnvironment.appBuildNumber),

        "API_BASE_URL": "$(API_BASE_URL)",
        "KAKAO_NATIVE_APP_KEY": "$(KAKAO_NATIVE_APP_KEY)",
        "GOOGLE_CLIENT_ID": "$(GOOGLE_CLIENT_ID)",
        "GOOGLE_REVERSED_CLIENT_ID": "$(GOOGLE_REVERSED_CLIENT_ID)",

        "UILaunchStoryboardName": "LaunchScreen",
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
        ],
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [:],
        ],

        // 카카오톡 설치/실행 가능 여부 조회
        "LSApplicationQueriesSchemes": [
            "kakaokompassauth",
            "kakaolink",
            "kakaoplus",
            "kakaotalk",
        ],

        "CFBundleURLTypes": [
            [
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleURLSchemes": ["dulpick"],
            ],
            [
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "kakao",
                "CFBundleURLSchemes": ["kakao$(KAKAO_NATIVE_APP_KEY)"],
            ],
            [
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "google",
                "CFBundleURLSchemes": ["$(GOOGLE_REVERSED_CLIENT_ID)"],
            ],
        ],
    ])

    public static let framework: InfoPlist = .default
    public static let test: InfoPlist = .default
}
