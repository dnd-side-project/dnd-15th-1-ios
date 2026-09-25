import Domain
@testable import Feature
import SharedDesignSystem
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
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { false }
            $0.onboardingClient.markAppIntroSeen = {
                markExp.fulfill()
            }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .appIntro(AppIntroFeature.State())
        }
        await fulfillment(of: [markExp], timeout: 1)
    }

    func test_세션없음_완료_로그아웃() async {
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
    }

    func test_세션복구실패_미완료_앱인트로() async {
        let markExp = expectation(description: "mark seen on intro entry after restore failure")
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { throw AuthError.storage }
            $0.onboardingClient.hasSeenAppIntro = { false }
            $0.onboardingClient.markAppIntroSeen = {
                markExp.fulfill()
            }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.failure)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .appIntro(AppIntroFeature.State())
        }
        await fulfillment(of: [markExp], timeout: 1)
    }

    func test_세션있음_메인_인트로스킵() async {
        let session = sampleSession
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: true, isNewMember: false)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success) {
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFlowFeature.State()
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
    }

    func test_세션있음_온보딩미완료_온보딩단계() async {
        let session = sampleSession
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: false, isNewMember: false)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
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
}

// 앱인트로·로그아웃 중 딥링크와 세션 만료만 따로 본다
@MainActor
final class RootFlowTransitionTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

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
                        myPage: MyPageFlowFeature.State()
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
            $0.phase = .onboardingFlow(
                OnboardingFlowFeature.State(
                    auth: AuthFeature.State(toast: ToastState(message: "로그아웃 되었습니다."))
                )
            )
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
        } withDependencies: {
            $0.notificationClient.requestAuthorization = { true }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
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
                    myPage: MyPageFlowFeature.State()
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
                    myPage: MyPageFlowFeature.State()
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
                        myPage: MyPageFlowFeature.State()
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

// 스플래시 최소 노출만 따로 본다
@MainActor
final class RootFlowSplashTests: XCTestCase {
    func test_스플래시는_최소_1초_머문다() async {
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .milliseconds(999))

        // 아직 1초가 안 됐다. 세션 복원이 끝났어도 최소 노출은 잠들어 있어야 한다.
        // checkSuspension 은 잠든 sleep 이 남아 있을 때 던진다
        do {
            try await clock.checkSuspension()
            XCTFail("최소 노출을 기다리지 않아 스플래시가 한 프레임만 스치고 사라진다")
        } catch {
            // 최소 노출이 아직 남아 있다
        }

        await clock.advance(by: .milliseconds(1))
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
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
        } withDependencies: {
            $0.notificationClient.requestAuthorization = { true }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
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

    func test_로그인성공_온보딩완료_알림_권한_요청() async {
        let authorizationCount = LockIsolated(0)
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.requestAuthorization = {
                authorizationCount.withValue { $0 += 1 }
                return true
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
        }

        await store.send(
            .onboardingFlow(
                .delegate(
                    .authenticated(userID: session.userID, isOnboardingCompleted: true)
                )
            )
        ) {
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFlowFeature.State()
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
        await store.finish()
        XCTAssertEqual(authorizationCount.value, 1)
    }

    func test_로그인성공_온보딩미완료_알림_권한_요청() async {
        let authorizationCount = LockIsolated(0)
        let session = sampleSession
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.requestAuthorization = {
                authorizationCount.withValue { $0 += 1 }
                return true
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
        }

        await store.send(
            .onboardingFlow(
                .delegate(
                    .authenticated(userID: session.userID, isOnboardingCompleted: false)
                )
            )
        )
        await store.finish()
        XCTAssertEqual(authorizationCount.value, 1)
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
                    myPage: MyPageFlowFeature.State()
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
                    myPage: MyPageFlowFeature.State()
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
                    myPage: MyPageFlowFeature.State()
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

@MainActor
final class RootFlowPushTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_로그인하면_FCM_토큰으로_기기를_등록한다() async {
        let registered = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.pushTokenStream = {
                AsyncStream { continuation in
                    continuation.yield("fcm-token")
                    continuation.finish()
                }
            }
            $0.notificationClient.registerDevice = { token in
                registered.withValue { $0.append(token) }
            }
            $0.notificationClient.requestAuthorization = { true }
        }
        store.exhaustivity = .off

        await store.send(
            .onboardingFlow(.delegate(.authenticated(userID: "42", isOnboardingCompleted: true)))
        )
        await store.finish()

        XCTAssertEqual(registered.value, ["fcm-token"])
    }

    func test_앱_재실행으로_세션을_복구해도_기기를_등록한다() async {
        let registered = LockIsolated<[String]>([])
        let session = sampleSession
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.pushTokenStream = {
                AsyncStream { continuation in
                    continuation.yield("fcm-token")
                    continuation.finish()
                }
            }
            $0.notificationClient.registerDevice = { token in
                registered.withValue { $0.append(token) }
            }
            $0.notificationClient.requestAuthorization = {
                XCTFail("앱 재실행에서는 권한을 다시 묻지 않는다")
                return false
            }
        }
        store.exhaustivity = .off

        await store.send(
            .sessionRestored(
                .success(
                    AuthBootstrap(
                        session: session,
                        isOnboardingCompleted: true,
                        isNewMember: false
                    )
                )
            )
        )
        await store.finish()

        XCTAssertEqual(registered.value, ["fcm-token"])
    }

    func test_마이페이지_로그아웃_뒤에는_새_토큰으로_등록하지_않는다() async {
        let registered = LockIsolated<[String]>([])
        let firstRegistered = expectation(description: "first token registered")
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(OnboardingFlowFeature.State())
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.pushTokenStream = { stream }
            $0.notificationClient.registerDevice = { token in
                registered.withValue { $0.append(token) }
                if token == "fcm-token" {
                    firstRegistered.fulfill()
                }
            }
            $0.notificationClient.requestAuthorization = { true }
        }
        store.exhaustivity = .off

        await store.send(
            .onboardingFlow(.delegate(.authenticated(userID: "42", isOnboardingCompleted: true)))
        )
        continuation.yield("fcm-token")
        await fulfillment(of: [firstRegistered], timeout: 1)

        await store.send(.mainTab(.delegate(.logoutSucceeded)))
        continuation.yield("fcm-token-after-logout")
        continuation.finish()
        await store.finish()

        XCTAssertEqual(registered.value, ["fcm-token"])
    }

    func test_온보딩완료_세션없으면_새_토큰으로_등록하지_않는다() async {
        let registered = LockIsolated<[String]>([])
        let firstRegistered = expectation(description: "first token registered")
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let session = sampleSession
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.notificationClient.pushTokenStream = { stream }
            $0.notificationClient.registerDevice = { token in
                registered.withValue { $0.append(token) }
                if token == "fcm-token" {
                    firstRegistered.fulfill()
                }
            }
            $0.notificationClient.requestAuthorization = {
                XCTFail("앱 재실행에서는 권한을 다시 묻지 않는다")
                return false
            }
            $0.authClient.currentSession = { nil }
        }
        store.exhaustivity = .off

        await store.send(
            .sessionRestored(
                .success(
                    AuthBootstrap(
                        session: session,
                        isOnboardingCompleted: false,
                        isNewMember: false
                    )
                )
            )
        )
        continuation.yield("fcm-token")
        await fulfillment(of: [firstRegistered], timeout: 1)

        await store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await store.receive(\.onboardingSessionResolved)
        continuation.yield("fcm-token-after-session-gone")
        continuation.finish()
        await store.finish()

        XCTAssertEqual(registered.value, ["fcm-token"])
    }
}

@MainActor
final class RootFlowAppOpenedAnalyticsTests: XCTestCase {
    func test_시작_액션이_오면_앱_실행_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }
        await store.finish()

        XCTAssertEqual(sent.value, [.appOpened])
    }

    func test_시작_액션을_두_번_보내도_앱_실행_이벤트는_한_번만_나간다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = { nil }
            $0.onboardingClient.hasSeenAppIntro = { true }
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success)
        await store.receive(\.bootstrapRoute) {
            $0.phase = .onboardingFlow(OnboardingFlowFeature.State())
        }

        await store.send(.onAppear)
        await store.finish()

        XCTAssertEqual(sent.value, [.appOpened])
    }
}

@MainActor
final class RootFlowAnalyticsTests: XCTestCase {
    func test_딥링크를_받으면_공유_진입_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        guard let url = URL(string: "dulpick://import?url=https://blog.example.com/post") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        guard let importURL = URL(string: "https://blog.example.com/post") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.deepLinkReceived(url))
        await store.receive(\.routeDeepLink) {
            $0.pendingDeepLink = .placeImport(url: importURL)
        }
        await store.finish()
        XCTAssertEqual(sent.value, [.shareImportStarted])
    }
}

@MainActor
final class RootFlowFeatureIdentityTests: XCTestCase {
    private let sampleSession = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_세션이_복구되면_사람을_묶는다() async {
        let identified = LockIsolated<[String]>([])
        let session = sampleSession
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: true, isNewMember: false)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
            $0.analyticsClient.identify = { userID in
                identified.withValue { $0.append(userID) }
            }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success) {
            $0.phase = .mainTab(
                MainTabFeature.State(
                    selectedTab: .home,
                    myPage: MyPageFlowFeature.State()
                )
            )
        }
        await store.receive(\.flushPendingDeepLink)
        await store.finish()

        XCTAssertEqual(identified.value, ["1"])
    }

    func test_로그아웃하면_묶음을_끊는다() async {
        let didReset = LockIsolated(false)
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .mainTab(
                    MainTabFeature.State(
                        myPage: MyPageFlowFeature.State()
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
            $0.analyticsClient.reset = {
                didReset.setValue(true)
            }
        }

        await store.send(.mainTab(.delegate(.logoutSucceeded))) {
            $0.phase = .onboardingFlow(
                OnboardingFlowFeature.State(
                    auth: AuthFeature.State(toast: ToastState(message: "로그아웃 되었습니다."))
                )
            )
        }
        await store.finish()

        XCTAssertTrue(didReset.value)
    }

    func test_온보딩_중_로그아웃하면_묶음을_끊는다() async {
        let didReset = LockIsolated(false)
        let store = TestStore(
            initialState: RootFlowFeature.State(
                phase: .onboardingFlow(
                    OnboardingFlowFeature.State(
                        nickname: NicknameFeature.State(),
                        path: [.nickname]
                    )
                )
            )
        ) {
            RootFlowFeature()
        } withDependencies: {
            $0.analyticsClient.reset = {
                didReset.setValue(true)
            }
        }

        // 스택은 이미 로그인 root 로 물러난 뒤 signedOut 만 올라온다
        await store.send(.onboardingFlow(.delegate(.signedOut)))
        await store.finish()

        XCTAssertTrue(didReset.value)
    }

    func test_온보딩_미완료_세션이_복구되면_사람을_묶는다() async {
        let identified = LockIsolated<[String]>([])
        let session = sampleSession
        let clock = TestClock()
        let store = TestStore(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.authClient.restoreSession = {
                AuthBootstrap(session: session, isOnboardingCompleted: false, isNewMember: false)
            }
            $0.onboardingClient.hasSeenAppIntro = {
                XCTFail("hasSeenAppIntro must not be called when session exists")
                return false
            }
            $0.notificationClient.pushTokenStream = { AsyncStream { $0.finish() } }
            $0.analyticsClient.identify = { userID in
                identified.withValue { $0.append(userID) }
            }
        }

        await store.send(.onAppear) {
            $0.didTrackAppOpened = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.sessionRestored.success) {
            $0.phase = .onboardingFlow(.resumingOnboarding)
        }
        await store.finish()

        XCTAssertEqual(identified.value, ["1"])
    }
}
