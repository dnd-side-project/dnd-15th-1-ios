import Foundation
import ThirdParty

@DependencyClient
public struct NotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async -> Bool = { false }
    /// FCM 등록 토큰을 흘린다. 구독하면 마지막 토큰을 먼저 준다
    public var fcmTokenStream: @Sendable () async -> AsyncStream<String> = { AsyncStream { $0.finish() } }
    /// 인자는 FCM 등록 토큰이다. 기기 해제는 로그아웃 경로가 Data 안에서 부른다
    public var registerDevice: @Sendable (String) async throws -> Void
}

extension NotificationClient: TestDependencyKey {
    public static let testValue = NotificationClient()
}

public extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
