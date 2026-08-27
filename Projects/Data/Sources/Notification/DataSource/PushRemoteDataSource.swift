import CoreNetwork
import Foundation

public struct PushRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func register(
        deviceID: String,
        body: PushDeviceRequestDTO
    ) async throws {
        try await networkClient.request(PushEndpoint.register(deviceID: deviceID, body: body))
    }

    /// 204 를 준다. body 가 없으므로 void 오버로드를 쓴다.
    func unregister(deviceID: String) async throws {
        try await networkClient.request(PushEndpoint.unregister(deviceID: deviceID))
    }
}
