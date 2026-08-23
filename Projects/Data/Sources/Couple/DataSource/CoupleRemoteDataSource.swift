import CoreNetwork
import Foundation

public struct CoupleRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func connectionCode() async throws -> ConnectionCodeResponseDTO {
        try await networkClient.request(CoupleEndpoint.connectionCode)
    }

    func connect(connectionCode: String) async throws -> CoupleConnectionStatusResponseDTO {
        try await networkClient.request(
            CoupleEndpoint.connect(connectionCode: connectionCode)
        )
    }

    func current() async throws -> CoupleConnectionStatusResponseDTO {
        try await networkClient.request(CoupleEndpoint.current)
    }

    func disconnect() async throws {
        try await networkClient.request(CoupleEndpoint.disconnect)
    }
}
