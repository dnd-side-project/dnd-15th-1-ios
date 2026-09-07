import SharedLogger
import ThirdPartyUI

/// 이벤트에 실어 보내는 값. 종류를 살려야 대시보드에서 참·거짓과 숫자로 거를 수 있다
public enum AnalyticsValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)

    /// 믹스패널이 참·거짓·숫자를 종류대로 받을 수 있게 바꾼다
    var mixpanelProperty: MixpanelType {
        switch self {
        case let .string(string):
            string
        case let .bool(bool):
            bool
        case let .int(int):
            int
        }
    }
}

/// 이벤트 하나를 믹스패널에 보낸다.
///
/// 초기화가 안 됐으면 아무 일도 하지 않는다. 이름을 짓는 것은 이 모듈의 일이 아니다
@MainActor
public enum AnalyticsEventSender {
    public static func track(name: String, properties: [String: AnalyticsValue]) {
        guard AnalyticsRuntime.isEnabled else {
            Logger.shared.info("믹스패널이 초기화되지 않아 이벤트를 건너뛴다 name=\(name)", category: .app)
            return
        }

        let mixpanelProperties: Properties = properties.mapValues(\.mixpanelProperty)
        Mixpanel.mainInstance().track(event: name, properties: mixpanelProperties)
    }
}
