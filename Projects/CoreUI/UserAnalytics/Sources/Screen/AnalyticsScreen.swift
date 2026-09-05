import ThirdPartyUI

/// 대시보드에 남길 화면 이름을 알린다.
///
/// SDK 의 화면 이름은 전역 값이라 명시로 바꾸기 전까지 유지된다.
/// 그래서 화면이 바뀔 때마다 반드시 다시 불러야 한다
public enum AnalyticsScreen {
    @MainActor
    public static func set(_ name: String) {
        _ = ClaritySDK.setCurrentScreenName(name)
    }
}
