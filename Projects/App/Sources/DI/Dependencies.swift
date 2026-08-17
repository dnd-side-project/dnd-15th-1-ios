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
        values.placeImportClient = PlaceImportClientFactory.make(session: authSession)

        // API 연동 전 임시 mock, 나중에 ExploreClientFactory 로 교체
        values.exploreClient = .mock

        values.placeClient = PlaceClientFactory.make(session: authSession)

        // API 연동 전 임시 mock, 나중에 CourseClientFactory 로 교체
        values.courseClient = .mock

        values.recentSearchClient = RecentSearchClientFactory.make(
            userDefaults: infra.userDefaults
        )

        values.onboardingClient = OnboardingClientFactory.make(
            userDefaults: infra.userDefaults
        )

        #if DEBUG
        DebugLaunchOverride.apply(to: &values)
        #endif
    }
}
