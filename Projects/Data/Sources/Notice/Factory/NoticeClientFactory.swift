import Domain
import Foundation

public enum NoticeClientFactory {
    /// 공지 목록은 한 페이지 20건 고정이라 여기서 넘긴다
    private static let pageSize = 20

    public static func make(session: AuthSessionAssembly) -> NoticeClient {
        let repository = NoticeRepository(
            remote: NoticeRemoteDataSource(networkClient: session.plainClient)
        )
        return NoticeClient(
            notices: { page in
                try await repository.notices(page: page, size: pageSize)
            }
        )
    }
}
