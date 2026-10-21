import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Foundation

/// Auth / Profile / Couple / Notification 이 공유하는 세션 조립 결과.
/// 세션 주인과 authed client 를 한 번만 만들어 모든 요청이 같은 세션과 같은 재발급을 본다.
public struct AuthSessionAssembly: Sendable {
    let plainClient: any NetworkClient
    let authedClient: any NetworkClient
    let sessionStore: AuthSessionStore
    let notificationLocal: NotificationLocalDataSource
    let socialAuth: SocialAuthCredentialProvider

    public static func make(
        keychain: any KeychainStorage,
        networkConfig: NetworkConfiguration,
        socialAuthClients: SocialAuthClients
    ) -> AuthSessionAssembly {
        let plainClient = NetworkClientFactory.plain(config: networkConfig)
        let notificationLocal = NotificationLocalDataSource(storage: keychain)
        let socialAuth = SocialAuthCredentialProvider(clients: socialAuthClients)
        let sessionStore = AuthSessionStore(
            authLocal: AuthLocalDataSource(storage: keychain),
            plainRemote: AuthRemoteDataSource(
                plainClient: plainClient,
                authedClient: plainClient
            )
        )
        let authedClient = NetworkClientFactory.authed(
            config: networkConfig,
            sessionProvider: sessionStore
        )

        return AuthSessionAssembly(
            plainClient: plainClient,
            authedClient: authedClient,
            sessionStore: sessionStore,
            notificationLocal: notificationLocal,
            socialAuth: socialAuth
        )
    }
}
