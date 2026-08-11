import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class AppCoordinatorFeatureTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_세션없음_미완료_앱인트로() async {
        let markExp = expectation(description: "mark seen on intro entry")
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { false }
            $0.onboardingClient.markAppIntroSeen = {
                markExp.fulfill()
            }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .appIntro(AppIntroFeature.State())
        }
        await fulfillment(of: [markExp], timeout: 1)
    }

    func test_세션없음_완료_로그아웃() async {
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }

    func test_세션복구실패_미완료_앱인트로() async {
        let markExp = expectation(description: "mark seen on intro entry after restore failure")
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { throw AuthError.storage }
            $0.onboardingClient.hasSeenAppIntro = { false }
            $0.onboardingClient.markAppIntroSeen = {
                markExp.fulfill()
            }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.failure)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .appIntro(AppIntroFeature.State())
        }
        await fulfillment(of: [markExp], timeout: 1)
    }

    func test_세션있음_메인_인트로스킵() async {
        let session = sampleSession
        let store = TestStore(initialState: AppCoordinatorFeature.State()) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { session }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success) {
            $0.currentUserID = session.userID
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(userID: session.userID)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_앱인트로완료_표시후_로그아웃() async {
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .appIntro(AppIntroFeature.State(pageIndex: 2))
            )
        ) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.onboardingClient.markAppIntroSeen = {
                XCTFail("markAppIntroSeen must be called on intro entry, not on completion")
            }
        }

        await store.send(.appIntro(.delegate(.completed)))
        await store.receive(\.appIntroFinished) {
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }

    func test_앱인트로중_홈딥링크_대기유지() async {
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .appIntro(AppIntroFeature.State())
            )
        ) {
            AppCoordinatorFeature()
        }

        await store.send(.routeDeepLink(.home)) {
            $0.pendingDeepLink = .home
            $0.phase = .appIntro(AppIntroFeature.State())
        }
    }

    func test_앱인트로중_로그인딥링크_대기안함() async {
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .appIntro(AppIntroFeature.State())
            )
        ) {
            AppCoordinatorFeature()
        }

        await store.send(.routeDeepLink(.signIn))
    }

    func test_메인로그아웃_로그아웃상태_인트로아님() async {
        let session = sampleSession
        let store = TestStore(
            initialState: AppCoordinatorFeature.State(
                phase: .main(
                    MainTabFeature.State(
                        myPage: MyPageFeature.State(userID: session.userID)
                    )
                ),
                currentUserID: session.userID
            )
        ) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be consulted on logout")
                return false
            }
        }

        await store.send(.mainTab(.delegate(.logoutSucceeded))) {
            $0.currentUserID = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
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
        await store.send(.auth(.delegate(.loginSucceeded(userID: session.userID)))) {
            $0.currentUserID = session.userID
            $0.phase = .main(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(userID: session.userID)
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
                    myPage: MyPageFeature.State(userID: session.userID)
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
                        myPage: MyPageFeature.State(userID: session.userID)
                    )
                ),
                currentUserID: session.userID
            )
        ) {
            AppCoordinatorFeature()
        } withDependencies: {
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be consulted on sessionExpired")
                return false
            }
        }

        await store.send(.sessionExpired) {
            $0.currentUserID = nil
            $0.phase = .loggedOut(AuthFeature.State())
        }
    }
}
