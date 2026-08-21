import CoreNotification
import Domain
import Foundation

public enum NotificationClientFactory {
    public static func make(client: RemoteNotificationClient) -> NotificationClient {
        NotificationClient(
            requestAuthorization: { await client.requestAuthorization() }
        )
    }
}
