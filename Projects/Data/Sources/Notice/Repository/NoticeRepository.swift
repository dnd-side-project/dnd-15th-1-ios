import Domain
import Foundation

public struct NoticeRepository: Sendable {
    private let remote: NoticeRemoteDataSource

    public init(remote: NoticeRemoteDataSource) {
        self.remote = remote
    }

    public func notices(page: Int, size: Int) async throws -> NoticePage {
        do {
            return NoticeDTOMapper.toDomain(try await remote.notices(page: page, size: size))
        } catch {
            throw NoticeErrorMapper.map(error)
        }
    }
}
