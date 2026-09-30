import ComposableArchitecture
@testable import Feature

/// 분석 클라이언트의 호출을 부른 순서대로 모은다.
struct AnalyticsRecorder: Sendable {
    enum Call: Equatable {
        case track(AnalyticsEvent)
        case identify(String)
        case markSignedUp
        case reset
    }

    private let recorded = LockIsolated<[Call]>([])

    /// 호출 넷을 부른 순서대로 돌려준다.
    var calls: [Call] { recorded.value }

    /// `track` 으로 보낸 이벤트만 순서대로 돌려준다.
    var events: [AnalyticsEvent] {
        recorded.value.compactMap { call in
            if case let .track(event) = call { return event }
            return nil
        }
    }

    /// 호출 넷을 모두 기록하는 클라이언트.
    var client: AnalyticsClient {
        AnalyticsClient(
            track: { [recorded] event in recorded.withValue { $0.append(.track(event)) } },
            identify: { [recorded] userID in recorded.withValue { $0.append(.identify(userID)) } },
            markSignedUp: { [recorded] _ in recorded.withValue { $0.append(.markSignedUp) } },
            reset: { [recorded] in recorded.withValue { $0.append(.reset) } }
        )
    }
}
