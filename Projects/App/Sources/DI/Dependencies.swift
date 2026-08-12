import Data
import Domain
import ThirdParty

enum Dependencies {
    @MainActor static func register(
        _ values: inout DependencyValues,
        infra: InfraContainer
    ) {
        let authSession = AuthSessionAssembly.make(
            keychain: infra.keychain,
            networkConfig: infra.networkConfig,
            socialAuthClients: infra.socialAuthClients
        )

        values.authClient = AuthClientFactory.make(session: authSession)
        values.profileClient = ProfileClientFactory.make(session: authSession)
        values.coupleClient = CoupleClientFactory.make(session: authSession)

        // API 연동 전 임시 mock, 나중에 ExploreClientFactory 로 교체
        values.exploreClient = .mock

        values.recentSearchClient = RecentSearchClientFactory.make(
            userDefaults: infra.userDefaults
        )

        values.onboardingClient = OnboardingClientFactory.make(
            userDefaults: infra.userDefaults
        )
    }
}
