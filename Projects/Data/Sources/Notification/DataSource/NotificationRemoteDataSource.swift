import CoreNetwork
import Foundation

public struct NotificationRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func register(
        deviceID: String,
        body: NotificationDeviceRequestDTO
    ) async throws {
        try await networkClient.request(NotificationEndpoint.register(deviceID: deviceID, body: body))
    }

    /// 204 를 준다. body 가 없으므로 void 오버로드를 쓴다.
    func unregister(deviceID: String) async throws {
        try await networkClient.request(NotificationEndpoint.unregister(deviceID: deviceID))
    }

    func settings() async throws -> NotificationSettingsResponseDTO {
        try await networkClient.request(NotificationEndpoint.settings)
    }

    func updateSettings(_ body: NotificationSettingsRequestDTO) async throws -> NotificationSettingsResponseDTO {
        try await networkClient.request(NotificationEndpoint.updateSettings(body))
    }
}
