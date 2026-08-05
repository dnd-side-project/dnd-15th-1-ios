import Data
import Domain
import ThirdParty

enum Dependencies {
    static func register(
        _ values: inout DependencyValues,
        infra: InfraContainer
    ) {
        values.authClient = AuthClientFactory.make(
            keychain: infra.keychain
        )
    }
}
