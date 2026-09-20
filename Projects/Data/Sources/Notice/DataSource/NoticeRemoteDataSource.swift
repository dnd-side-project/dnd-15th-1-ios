import CoreNetwork
import Foundation

public struct NoticeRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func notices(page: Int, size: Int) async throws -> NoticePageResponseDTO {
        try await networkClient.request(NoticeEndpoint.notices(page: page, size: size))
    }
}
