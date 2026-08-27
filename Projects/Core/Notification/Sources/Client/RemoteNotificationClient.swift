import Foundation
import SharedLogger
import ThirdPartyCore
import UIKit
import UserNotifications

@MainActor
public final class RemoteNotificationClient: NSObject {
    private var latestToken: String?
    private var continuations: [UUID: AsyncStream<String>.Continuation] = [:]

    override init() {
        super.init()
    }

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            Logger.shared.info("알림 권한 요청 결과 granted=\(granted)", category: .app)
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            Logger.shared.error("알림 권한 요청 실패 \(error)", category: .app)
            return false
        }
    }

    /// 이미 허용된 상태면 APNs 등록을 다시 부른다. 물어본 적 없으면 아무것도 하지 않는다.
    public func registerIfAuthorized() async {
        let status = await Self.authorizationStatus()
        guard status == .authorized else {
            Logger.shared.info(
                "알림 권한이 없어 APNs 등록을 건너뛴다 status=\(status.rawValue)",
                category: .app
            )
            return
        }
        Logger.shared.info("이미 허용된 상태라 APNs 등록을 부른다", category: .app)
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// `UNNotificationSettings` 는 Sendable 이 아니라 격리 경계를 못 넘는다. 상태 값만 꺼내 넘긴다.
    private nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// FCM 등록 토큰을 내보낸다. 구독 시 마지막 토큰을 먼저 흘린다.
    public func fcmTokenStream() -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream<String>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        let id = UUID()
        continuations[id] = continuation
        if let latestToken {
            continuation.yield(latestToken)
        }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuations[id] = nil
            }
        }
        return stream
    }

    public func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Logger.shared.info("APNs 토큰 전달 완료", category: .app)
    }

    public func registrationDidFail(_ error: any Error) {
        Logger.shared.error("APNs 등록 실패 \(error)", category: .app)
    }

    func emit(token: String) {
        latestToken = token
        Logger.shared.info("FCM 토큰 \(token)", category: .app)
        for continuation in continuations.values {
            continuation.yield(token)
        }
    }
}

extension RemoteNotificationClient: MessagingDelegate {
    public nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.emit(token: fcmToken)
        }
    }
}

extension RemoteNotificationClient: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}
