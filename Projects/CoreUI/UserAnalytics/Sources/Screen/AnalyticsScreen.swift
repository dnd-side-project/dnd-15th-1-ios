import SharedLogger
import ThirdPartyUI

/// 대시보드에 남길 화면 이름을 알린다.
///
/// SDK 의 화면 이름은 전역 값이라 명시로 바꾸기 전까지 유지된다.
/// 그래서 화면이 바뀔 때마다 반드시 다시 불러야 한다
public enum AnalyticsScreen {
    /// SDK 는 비어 있지 않고 255자 이하인 이름만 받는다. 어긋나면 이전 이름이 그대로 남는다
    @MainActor
    public static func set(_ name: String) {
        guard ClaritySDK.setCurrentScreenName(name) else {
            Logger.shared.error("클라리티 화면 이름 설정에 실패했다 name=\(name)", category: .app)
            return
        }
    }
}
