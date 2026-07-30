import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class AppCoordinatorFeatureTests: XCTestCase {
    func test_세션없음_로그아웃상태복구() async {
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored) {
            $0.currentUser = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }

    func test_세션있음_메인상태복구() async {
        let user = AuthUser(id: "1")
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.currentUser = { user }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored) {
            $0.currentUser = user
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(user: user)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_로그아웃중_딥링크대기후_로그인시이동() async {
        let user = AuthUser(id: "1")
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
        await store.send(.auth(.delegate(.signInSucceeded(user)))) {
            $0.currentUser = user
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(user: user)
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
                    myPage: MyPageFeature.State(user: user)
                )
            )
        }
    }

    func test_세션만료_로그아웃상태전환() async {
        let user = AuthUser(id: "1")
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .main(MainTabFeature.State(myPage: MyPageFeature.State(user: user))),
                currentUser: user
            )
        ) {
            AppCoordinatorFeature()
        }

        await store.send(.sessionExpired) {
            $0.currentUser = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }
}
