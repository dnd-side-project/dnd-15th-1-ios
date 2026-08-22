import Foundation

public struct RemoteNotificationClientFactory: Sendable {
    public init() {}

    @MainActor
    public func make() -> RemoteNotificationClient {
        RemoteNotificationClient()
    }
}
