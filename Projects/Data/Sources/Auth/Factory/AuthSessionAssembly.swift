import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Foundation

/// Auth / Profile / Couple 이 공유하는 세션 조립 결과.
/// authed client 를 한 번만 만들어 토큰 재발급 single-flight 를 공유한다.
public struct AuthSessionAssembly: Sendable {
    let plainClient: any NetworkClient
    let authedClient: any NetworkClient
    let authLocal: AuthLocalDataSource
    let socialAuth: SocialAuthCredentialProvider

    public static func make(
        keychain: any KeychainStorage,
        networkConfig: NetworkConfiguration,
        socialAuthClients: SocialAuthClients
    ) -> AuthSessionAssembly {
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

        return AuthSessionAssembly(
            plainClient: plainClient,
            authedClient: authedClient,
            authLocal: authLocal,
            socialAuth: socialAuth
        )
    }
}
