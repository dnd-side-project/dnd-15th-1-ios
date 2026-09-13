import Foundation
import SharedLogger
import ThirdPartyUI

/// 이벤트를 보낸 사람이 누구인지 믹스패널에 알린다.
///
/// 초기화가 안 됐으면 아무 일도 하지 않는다
@MainActor
public enum AnalyticsIdentity {
    /// 로그인이 성공한 때와 앱을 다시 켜서 세션이 복구된 때 부른다
    public static func identify(userID: String) {
        guard AnalyticsRuntime.isEnabled else {
            Logger.shared.info("믹스패널이 초기화되지 않아 사람 묶기를 건너뛴다", category: .app)
            return
        }

        Mixpanel.mainInstance().identify(distinctId: userID)
    }

    /// 가입일을 한 번만 적는다. 이미 적힌 값이 있으면 덮어쓰지 않는다
    public static func markSignedUp(at date: Date) {
        guard AnalyticsRuntime.isEnabled else {
            Logger.shared.info("믹스패널이 초기화되지 않아 가입일 적기를 건너뛴다", category: .app)
            return
        }

        Mixpanel.mainInstance().people.setOnce(properties: ["$created": date])
    }

    /// 로그아웃·탈퇴·세션 만료에서 부른다. SDK 가 끊기 전에 쌓인 이벤트를 보낸다
    public static func reset() {
        guard AnalyticsRuntime.isEnabled else {
            Logger.shared.info("믹스패널이 초기화되지 않아 묶음 끊기를 건너뛴다", category: .app)
            return
        }

        Mixpanel.mainInstance().reset()
    }
}
