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

        values.exploreClient = ExploreClientFactory.make(session: authSession)

        values.placeClient = PlaceClientFactory.make(session: authSession)
        values.courseClient = CourseClientFactory.make(session: authSession)

        values.recentSearchClient = RecentSearchClientFactory.make(
            userDefaults: infra.userDefaults
        )

        values.mapRecentSearchClient = RecentSearchClientFactory.make(
            userDefaults: infra.userDefaults,
            key: "map-recent-searches"
        )

        values.onboardingClient = OnboardingClientFactory.make(
            userDefaults: infra.userDefaults
        )

        #if DEBUG
        DebugLaunchOverride.apply(to: &values)
        #endif
    }
}
