import ProjectDescription

/// Tuist 공통 환경 상수.
/// 빌드 타임 기준값. 런타임 값은 Config/Info.plist → AppInfo로 읽는다.
public enum ProjectEnvironment {
    public static let organizationName = "com.dulpick"
    public static let bundlePrefix = "com.dulpick"
    public static let productName = "Dulpick"
    public static let displayName = "둘픽"

    public static let appVersion = "1.0.1"
    public static let appBuildNumber = "2"

    public static let swiftVersion = "6"
    public static let deploymentTarget = "18.0"
    public static let destinations: Destinations = .iOS

    public static let debugConfigName: ConfigurationName = .debug
    public static let releaseConfigName: ConfigurationName = .release

    public enum AppBundle {
        public static let debug = "\(ProjectEnvironment.bundlePrefix).debug"
        public static let release = "\(ProjectEnvironment.bundlePrefix).app"
    }

    /// 딥링크 주소. 개발 앱과 배포 앱이 한 기기에 같이 깔려도 서로를 열지 않게 가른다.
    /// 배포 값 `dulpick` 은 출시된 앱이 쓰는 값이라 바꾸면 밖에 나간 링크가 깨진다.
    public enum URLScheme {
        public static let debug = "dulpickdebug"
        public static let release = "dulpick"
    }

    public static func moduleBundleId(_ suffix: String) -> String {
        "\(bundlePrefix).\(suffix)"
    }
}
