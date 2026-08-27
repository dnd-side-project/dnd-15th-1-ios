import Foundation
import SharedLogger
import ThirdPartyCore
import UserNotifications

public enum NotificationBootstrap {
    @MainActor
    public static func run(
        _ config: NotificationConfiguration,
        client: RemoteNotificationClient
    ) {
        guard let options = makeOptions(config) else {
            Logger.shared.error(
                "Firebase 설정 파일을 찾지 못해 초기화를 건너뛴다 name=\(config.firebaseOptionsResourceName)",
                category: .app
            )
            return
        }

        FirebaseApp.configure(options: options)
        Messaging.messaging().delegate = client
        UNUserNotificationCenter.current().delegate = client

        Logger.shared.info("Firebase 초기화 완료 project=\(options.projectID ?? "-")", category: .app)
        Task { await client.registerIfAuthorized() }
    }

    private static func makeOptions(_ config: NotificationConfiguration) -> FirebaseOptions? {
        guard
            let path = Bundle.main.path(
                forResource: config.firebaseOptionsResourceName,
                ofType: "plist"
            ),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            return nil
        }
        return options
    }
}
