import CoreUserAnalytics
import Foundation
import ThirdParty

/// 리듀서가 이벤트를 보낼 때 쓰는 창구. 테스트가 이 자리에 가짜를 꽂는다
@DependencyClient
struct AnalyticsClient: Sendable {
    var track: @Sendable (AnalyticsEvent) async -> Void = { _ in }
    var identify: @Sendable (String) async -> Void = { _ in }
    var markSignedUp: @Sendable (Date) async -> Void = { _ in }
    var reset: @Sendable () async -> Void = {}
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient(
        track: { event in
            await MainActor.run {
                AnalyticsEventSender.track(name: event.name, properties: event.properties)
            }
        },
        identify: { userID in
            await MainActor.run {
                AnalyticsIdentity.identify(userID: userID)
            }
        },
        markSignedUp: { date in
            await MainActor.run {
                AnalyticsIdentity.markSignedUp(at: date)
            }
        },
        reset: {
            await MainActor.run {
                AnalyticsIdentity.reset()
            }
        }
    )

    /// 이벤트를 보내는 것은 화면 동작에 영향을 주지 않는다. 테스트에서는 아무 일도 안 하는 것이
    /// 기본이고, 이벤트를 확인하려는 테스트만 이 자리에 가짜를 꽂는다
    static let testValue = AnalyticsClient(
        track: { _ in },
        identify: { _ in },
        markSignedUp: { _ in },
        reset: {}
    )
}

extension DependencyValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
