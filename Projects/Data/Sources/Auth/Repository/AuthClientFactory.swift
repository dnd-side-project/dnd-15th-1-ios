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
            currentUser: {
                try await impl.currentUser()
            },
            signIn: {
                try await impl.signIn()
            },
            signOut: {
                try await impl.signOut()
            }
        )
    }
}
