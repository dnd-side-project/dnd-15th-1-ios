import CoreNotification
import SharedLogger
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    var remoteNotificationClient: RemoteNotificationClient?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard let remoteNotificationClient else {
            Logger.shared.error("APNs 토큰이 왔는데 알림 클라이언트가 주입되지 않았다", category: .app)
            return
        }
        remoteNotificationClient.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        guard let remoteNotificationClient else {
            Logger.shared.error("APNs 등록 실패가 왔는데 알림 클라이언트가 주입되지 않았다", category: .app)
            return
        }
        remoteNotificationClient.registrationDidFail(error)
    }
}
