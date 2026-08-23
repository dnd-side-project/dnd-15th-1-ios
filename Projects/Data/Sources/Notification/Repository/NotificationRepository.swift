import CoreNetwork
import Domain
import Foundation

public struct NotificationRepository: Sendable {
    private let pushRemote: PushRemoteDataSource
    private let pushLocal: PushLocalDataSource
    private let appVersion: String?

    public init(
        pushRemote: PushRemoteDataSource,
        pushLocal: PushLocalDataSource,
        appVersion: String?
    ) {
        self.pushRemote = pushRemote
        self.pushLocal = pushLocal
        self.appVersion = appVersion
    }

    public func registerDevice(token: String) async throws {
        do {
            let deviceID = try await pushLocal.deviceID()
            try await pushRemote.register(
                deviceID: deviceID,
                body: PushDTOMapper.toRequest(token: token, appVersion: appVersion)
            )
        } catch {
            throw PushErrorMapper.map(error)
        }
    }

    /// 이미 해제된 디바이스를 또 불러도 성공으로 본다. 명세가 멱등이라고 적었다.
    public func unregisterDevice() async throws {
        do {
            let deviceID = try await pushLocal.deviceID()
            try await pushRemote.unregister(deviceID: deviceID)
        } catch {
            if let networkError = error as? NetworkError, case .notFound = networkError {
                return
            }
            throw PushErrorMapper.map(error)
        }
    }
}
