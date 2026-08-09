import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Domain
import Foundation

public enum AuthClientFactory {
    public static func make(
        keychain: any KeychainStorage,
        networkConfig: NetworkConfiguration,
        socialAuthClients: SocialAuthClients
    ) -> AuthClient {
        let repository = makeRepo(
            keychain: keychain,
            networkConfig: networkConfig,
            socialAuthClients: socialAuthClients
        )
        return makeClient(repository: repository)
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

    private static func makeRepo(
        keychain: any KeychainStorage,
        networkConfig: NetworkConfiguration,
        socialAuthClients: SocialAuthClients
    ) -> AuthRepository {
        let plainClient = NetworkClientFactory.plain(config: networkConfig)
        let authLocal = AuthLocalDataSource(storage: keychain)
        let socialAuth = SocialAuthCredentialProvider(clients: socialAuthClients)
        let plainRemote = AuthRemoteDataSource(
            plainClient: plainClient,
            authedClient: plainClient
        )
        let tokenBridge = AuthTokenBridge(
            authLocal: authLocal,
            plainRemote: plainRemote
        )
        let authedClient = NetworkClientFactory.authed(
            config: networkConfig,
            tokenProvider: tokenBridge,
            tokenRefresher: tokenBridge
        )

        let authRemote = AuthRemoteDataSource(
            plainClient: plainClient,
            authedClient: authedClient
        )
        return AuthRepository(
            authRemote: authRemote,
            authLocal: authLocal,
            socialAuth: socialAuth
        )
    }
}
