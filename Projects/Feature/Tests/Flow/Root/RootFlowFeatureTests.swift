import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class RootFlowFeatureTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_세션없음_미완료_앱인트로() async {
        let markExp = expectation(description: "mark seen on intro entry")
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
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
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_세션복구실패_미완료_앱인트로() async {
        let markExp = expectation(description: "mark seen on intro entry after restore failure")
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
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
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: true)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success) {
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(userID: session.userID)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_세션있음_온보딩미완료_온보딩단계() async {
        let session = sampleSession
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: false)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
        }

        await store.send(.onAppear)
        await store.receive(\.sessionRestored.success) {
            $0.phase = .onboardingFlow(.resumingOnboarding)
        }
    }

    func test_앱인트로완료_표시후_로그아웃() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .appIntro(AppIntroFeature.State(pageIndex: 2))
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.onboardingClient.markAppIntroSeen = {
                XCTFail("markAppIntroSeen must be called on intro entry, not on completion")
            }
        }

        await store.send(.appIntro(.delegate(.completed)))
        await store.receive(\.appIntroFinished) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_앱인트로중_홈딥링크_대기유지() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .appIntro(AppIntroFeature.State())
            )
        ) {
            RootFlowFeature()
        }

        await store.send(.routeDeepLink(.home)) {
            $0.pendingDeepLink = .home
            $0.phase = .appIntro(AppIntroFeature.State())
        }
    }

    func test_앱인트로중_로그인딥링크_대기안함() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .appIntro(AppIntroFeature.State())
            )
        ) {
            RootFlowFeature()
        }

        await store.send(.routeDeepLink(.signIn))
    }

    func test_메인로그아웃_로그아웃상태_인트로아님() async {
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .mainTab(
                    MainTabFeature.State(
                        myPage: MyPageFeature.State(userID: session.userID)
                    )
                )
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be consulted on logout")
                return false
            }
        }

        await store.send(.mainTab(.delegate(.logoutSucceeded))) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_로그아웃중_딥링크대기후_로그인시이동() async {
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.routeDeepLink(.map)) {
            $0.pendingDeepLink = .map
        }
        await store.send(
            .onboardingFlow(
                .auth(
                    .delegate(
                        .loginSucceeded(userID: session.userID, isOnboardingCompleted: true)
                    )
                )
            )
        )
        await store.receive(\.onboardingFlow.delegate.authenticated) {
            $0.phase = .mainTab(
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
            $0.phase = .mainTab(
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
            initialState: RootFlowFeature.State(
                phase: .mainTab(
                    MainTabFeature.State(
                        myPage: MyPageFeature.State(userID: session.userID)
                    )
                )
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be consulted on sessionExpired")
                return false
            }
        }

        await store.send(.sessionExpired) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }
}

// 온보딩 단계 분기만 따로 본다
@MainActor
final class RootFlowOnboardingTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_로그인성공_온보딩미완료_닉네임이_올라간다() async {
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        }

        await store.send(
            .onboardingFlow(
                .auth(
                    .delegate(
                        .loginSucceeded(userID: session.userID, isOnboardingCompleted: false)
                    )
                )
            )
        ) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State(path: [.nickname]))
        }
        await store.receive(\.onboardingFlow.delegate.authenticated)
    }

    func test_온보딩에서_로그아웃되면_로그인화면_그대로다() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        }

        await store.send(.onboardingFlow(.delegate(.signedOut)))

        XCTAssertEqual(store.state.phase, .onboardingFlow(OnboardingFlowFeature.State()))
    }

    func test_온보딩완료_세션있음_메인이동() async {
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding)
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.currentSession = { session }
        }

        await store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await store.receive(\.onboardingSessionResolved) {
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFeature.State(userID: session.userID)
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_온보딩완료_세션없음_로그인으로() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding)
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.currentSession = { nil }
        }

        await store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await store.receive(\.onboardingSessionResolved) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_온보딩완료_세션조회실패_로그인으로() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding)
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.currentSession = { throw AuthError.storage }
        }

        await store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await store.receive(\.onboardingSessionResolved) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_온보딩완료_메인이동_대기딥링크반영() async {
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding),
                pendingDeepLink: .map
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.authClient.currentSession = { session }
        }

        await store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await store.receive(\.onboardingSessionResolved) {
            $0.phase = .mainTab(
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
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .map,
                    myPage: MyPageFeature.State(userID: session.userID)
                )
            )
        }
    }

    func test_온보딩중_세션만료_로그아웃() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding)
            )
        ) {
            RootFlowFeature()
        }

        await store.send(.onboardingFlow(.delegate(.sessionExpired)))
        await store.receive(\.sessionExpired) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_온보딩중_홈딥링크_대기유지_로그인딥링크_무시() async {
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(.resumingOnboarding)
            )
        ) {
            RootFlowFeature()
        }

        await store.send(.routeDeepLink(.home)) {
            $0.pendingDeepLink = .home
        }
        await store.send(.routeDeepLink(.signIn))
    }
}
