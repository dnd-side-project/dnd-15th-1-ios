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
            fcmTokenStream: { await client.fcmTokenStream() },
            registerDevice: { try await repository.registerDevice(token: $0) }
        )
    }

    static func makeRepository(session: AuthSessionAssembly) -> NotificationRepository {
        NotificationRepository(
            pushRemote: PushRemoteDataSource(networkClient: session.authedClient),
            pushLocal: session.pushLocal,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }
}
