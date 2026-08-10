import Data
import Domain
import ThirdParty

enum Dependencies {
    @MainActor static func register(
        _ values: inout DependencyValues,
        infra: InfraContainer
    ) {
        values.authClient = AuthClientFactory.make(
            keychain: infra.keychain,
            networkConfig: infra.networkConfig,
            socialAuthClients: infra.socialAuthClients
        )
    }
}
