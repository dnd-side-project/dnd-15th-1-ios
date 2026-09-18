import CoreNotification
import Domain
import Foundation

public enum NotificationClientFactory {
    public static func make(
        session: AuthSessionAssembly,
        client: RemoteNotificationClient
    ) -> NotificationClient {
        let repository = makeRepository(session: session)
        return NotificationClient(
            requestAuthorization: { await client.requestAuthorization() },
            pushTokenStream: { await client.fcmTokenStream() },
            registerDevice: { try await repository.registerDevice(token: $0) },
            notificationSettings: { try await repository.notificationSettings() },
            updateNotificationSettings: { try await repository.updateNotificationSettings($0) }
        )
    }

    static func makeRepository(session: AuthSessionAssembly) -> NotificationRepository {
        NotificationRepository(
            notificationRemote: NotificationRemoteDataSource(networkClient: session.authedClient),
            notificationLocal: session.notificationLocal,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }
}
