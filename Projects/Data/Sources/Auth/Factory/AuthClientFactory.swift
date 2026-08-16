import Domain
import Foundation

public enum AuthClientFactory {
    public static func make(session: AuthSessionAssembly) -> AuthClient {
        makeClient(repository: makeRepo(session: session))
    }

    private static func makeClient(repository: AuthRepository) -> AuthClient {
        AuthClient(
            restoreSession: {
                try await repository.restoreSession()
            },
            login: { provider in
                try await repository.login(provider: provider)
            },
            logout: {
                try await repository.logout()
            },
            currentSession: {
                try await repository.currentSession()
            }
        )
    }

    private static func makeRepo(session: AuthSessionAssembly) -> AuthRepository {
        let authRemote = AuthRemoteDataSource(
            plainClient: session.plainClient,
            authedClient: session.authedClient
        )
        return AuthRepository(
            authRemote: authRemote,
            authLocal: session.authLocal,
            socialAuth: session.socialAuth,
            profileRemote: ProfileRemoteDataSource(networkClient: session.authedClient)
        )
    }
}
