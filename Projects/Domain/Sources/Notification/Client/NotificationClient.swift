import ThirdParty

@DependencyClient
public struct NotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async -> Bool = { false }
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
