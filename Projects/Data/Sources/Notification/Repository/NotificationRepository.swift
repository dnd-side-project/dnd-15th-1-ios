import CoreNetwork
import Domain
import Foundation

public struct NotificationRepository: Sendable {
    private let notificationRemote: NotificationRemoteDataSource
    private let notificationLocal: NotificationLocalDataSource
    private let appVersion: String?

    public init(
        notificationRemote: NotificationRemoteDataSource,
        notificationLocal: NotificationLocalDataSource,
        appVersion: String?
    ) {
        self.notificationRemote = notificationRemote
        self.notificationLocal = notificationLocal
        self.appVersion = appVersion
    }

    public func registerDevice(token: String) async throws {
        do {
            let deviceID = try await notificationLocal.deviceID()
            try await notificationRemote.register(
                deviceID: deviceID,
                body: NotificationDTOMapper.toRequest(token: token, appVersion: appVersion)
            )
        } catch {
            throw NotificationErrorMapper.map(error)
        }
    }

    /// 이미 해제된 디바이스를 또 불러도 성공으로 본다. 명세가 멱등이라고 적었다.
    public func unregisterDevice() async throws {
        do {
            let deviceID = try await notificationLocal.deviceID()
            try await notificationRemote.unregister(deviceID: deviceID)
        } catch {
            if let networkError = error as? NetworkError, case .notFound = networkError {
                return
            }
            throw NotificationErrorMapper.map(error)
        }
    }

    public func notificationSettings() async throws -> NotificationSettings {
        do {
            return NotificationDTOMapper.toDomain(try await notificationRemote.settings())
        } catch {
            throw NotificationErrorMapper.map(error)
        }
    }

    public func updateNotificationSettings(
        _ settings: NotificationSettings
    ) async throws -> NotificationSettings {
        do {
            let dto = try await notificationRemote.updateSettings(
                NotificationDTOMapper.toRequest(settings)
            )
            return NotificationDTOMapper.toDomain(dto)
        } catch {
            throw NotificationErrorMapper.map(error)
        }
    }
}
