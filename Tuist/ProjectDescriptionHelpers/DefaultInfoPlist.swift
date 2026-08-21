import ProjectDescription

public enum DefaultInfoPlist {
    public static let app: InfoPlist = .extendingDefault(with: [
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "CFBundleShortVersionString": .string(ProjectEnvironment.appVersion),
        "CFBundleVersion": .string(ProjectEnvironment.appBuildNumber),
        // 수출 규제 면제 대상. OS 가 주는 HTTPS 와 애플 프레임워크만 쓴다
        "ITSAppUsesNonExemptEncryption": false,
        "FirebaseAppDelegateProxyEnabled": false,

        "API_BASE_URL": "$(API_BASE_URL)",
        "KAKAO_NATIVE_APP_KEY": "$(KAKAO_NATIVE_APP_KEY)",
        "GOOGLE_CLIENT_ID": "$(GOOGLE_CLIENT_ID)",
        "GOOGLE_REVERSED_CLIENT_ID": "$(GOOGLE_REVERSED_CLIENT_ID)",
        "FIREBASE_OPTIONS_RESOURCE": "$(FIREBASE_OPTIONS_RESOURCE)",

        "UILaunchStoryboardName": "LaunchScreen",
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
        ],
        "UIUserInterfaceStyle": "Light",
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
