import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class AppCoordinatorFeatureTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userId: "1"
    )

    func test_세션없음_로그아웃상태복구() async {
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { nil }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored) {
            $0.currentSession = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }

    func test_세션있음_메인상태복구() async {
        let session = sampleSession
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { session }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored) {
            $0.currentSession = session
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(session: session)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_로그아웃중_딥링크대기후_로그인시이동() async {
        let session = sampleSession
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .loggedOut(AuthFeature.State())
            )
        ) {
            AppCoordinatorFeature()
        }
        store.exhaustivity = .off

        await store.send(.routeDeepLink(.map)) {
            $0.pendingDeepLink = .map
        }
        await store.send(.auth(.delegate(.loginSucceeded(session)))) {
            $0.currentSession = session
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(session: session)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink) {
            $0.pendingDeepLink = nil
        }
        await store.receive(\.routeDeepLink) {
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .map,
                    myPage: MyPageFeature.State(session: session)
                )
            )
        }
    }

    func test_세션만료_로그아웃상태전환() async {
        let session = sampleSession
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .main(
                    MainTabFeature.State(
                        myPage: MyPageFeature.State(session: session)
                    )
                ),
                currentSession: session
            )
        ) {
            AppCoordinatorFeature()
        }

        await store.send(.unauthorized) {
            $0.currentSession = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }
}
