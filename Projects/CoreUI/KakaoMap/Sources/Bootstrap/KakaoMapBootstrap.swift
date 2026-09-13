import ThirdPartyUI

/// 카카오맵 SDK 초기화.
///
/// App 이 앱 시작 때 한 번 부른다. SDK 를 아는 것은 이 모듈뿐이다
public enum KakaoMapBootstrap {
    @MainActor
    public static func run(appKey: String) {
        SDKInitializer.InitSDK(appKey: appKey)
    }
}
