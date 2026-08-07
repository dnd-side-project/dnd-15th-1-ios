import CoreStorage
import Domain
import Foundation

public enum AuthClientFactory {
    public static func make(
        keychain: any KeychainStorage
    ) -> AuthClient {
        let impl = AuthRepositoryImpl(
            authRemote: AuthRemoteDatasource(),
            authLocal: AuthLocalDatasource(storage: keychain)
        )

        return AuthClient(
            restoreSession: {
                try await impl.restoreSession()
            },
            login: { provider in
                try await impl.login(provider: provider)
            },
            logout: {
                try await impl.logout()
            },
            currentSession: {
                try await impl.currentSession()
            }
        )
    }
}
