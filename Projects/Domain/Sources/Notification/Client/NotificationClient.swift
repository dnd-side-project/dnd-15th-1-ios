import Foundation
import ThirdParty

@DependencyClient
public struct NotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async -> Bool = { false }
    /// 푸시 등록 토큰을 흘린다. 구독하면 마지막 토큰을 먼저 준다
    public var pushTokenStream: @Sendable () async -> AsyncStream<String> = { AsyncStream { $0.finish() } }
    /// 인자는 푸시 등록 토큰이다. 기기 해제는 로그아웃 경로가 Data 안에서 부른다
    public var registerDevice: @Sendable (String) async throws -> Void
    /// 콘텐츠 저장·데이트 일정·마케팅 알림을 받을지
    public var notificationSettings: @Sendable () async throws -> NotificationSettings
    /// 세 값을 통째로 바꾼다. 마케팅을 켤 때는 동의한 약관 버전을 함께 보낸다
    public var updateNotificationSettings: @Sendable (NotificationSettings) async throws -> NotificationSettings
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
