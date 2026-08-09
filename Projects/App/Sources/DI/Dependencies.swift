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

        // API 연동 전 임시 mock, 나중에 ExploreClientFactory 로 교체
        values.exploreClient = .mock
    }
}
