import Domain
import Foundation

public enum CoupleClientFactory {
    public static func make(session: AuthSessionAssembly) -> CoupleClient {
        makeClient(repository: makeRepo(session: session))
    }

    private static func makeClient(repository: CoupleRepository) -> CoupleClient {
        CoupleClient(
            inviteCode: {
                try await repository.inviteCode()
            },
            connect: { inviteCode in
                try await repository.connect(inviteCode: inviteCode)
            },
            current: {
                try await repository.current()
            }
        )
    }

    private static func makeRepo(session: AuthSessionAssembly) -> CoupleRepository {
        CoupleRepository(
            coupleRemote: CoupleRemoteDataSource(networkClient: session.authedClient)
        )
    }
}
