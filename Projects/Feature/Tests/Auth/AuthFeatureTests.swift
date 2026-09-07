import Domain
@testable import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class AuthFeatureTests: XCTestCase {
    private let session = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_카카오_로그인_성공_델리게이트_전달() async {
        await assertLoginSuccess(provider: .kakao)
    }

    func test_애플_로그인_성공_델리게이트_전달() async {
        await assertLoginSuccess(provider: .apple)
    }

    func test_구글_로그인_성공_델리게이트_전달() async {
        await assertLoginSuccess(provider: .google)
    }

    func test_온보딩_미완료_로그인_델리게이트_전달() async {
        await assertLoginSuccess(provider: .kakao, isOnboardingCompleted: false)
    }

    func test_loginFailed_토스트() async {
        await assertLoginFailure(
            error: .loginFailed,
            expectedMessage: "로그인에 실패했습니다."
        )
    }

    func test_network_토스트() async {
        await assertLoginFailure(
            error: .network,
            expectedMessage: "네트워크 연결을 확인해 주세요."
        )
    }

    func test_unknown_토스트() async {
        await assertLoginFailure(
            error: .unknown,
            expectedMessage: "잠시 후 다시 시도해 주세요."
        )
    }

    func test_unauthorized_토스트() async {
        await assertLoginFailure(
            error: .unauthorized,
            expectedMessage: "잠시 후 다시 시도해 주세요."
        )
    }
    func test_cancelled_토스트_없음() async {
        let loginCount = LockIsolated(0)
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.login = { _ in
                loginCount.withValue { $0 += 1 }
                throw AuthError.cancelled
            }
        }

        await store.send(.loginButtonTapped(.kakao)) {
            $0.isLoading = true
            $0.loadingProvider = .kakao
            $0.toast = nil
        }
        await store.receive(\.loginResponse.failure) {
            $0.isLoading = false
            $0.loadingProvider = nil
        }
        XCTAssertEqual(loginCount.value, 1)
    }

    func test_신규_회원의_로그인_성공에만_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.loginResponse(.success(AuthBootstrapFixtures.fixtureNewMember(session: session))))
        await store.receive(
            .delegate(
                .loginSucceeded(
                    userID: session.userID,
                    isOnboardingCompleted: true
                )
            )
        )
        await store.finish()
        XCTAssertEqual(sent.value, [.loginStarted])
    }

    func test_기존_회원의_로그인에는_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.loginResponse(.success(AuthBootstrapFixtures.fixtureExistingMember(session: session))))
        await store.receive(
            .delegate(
                .loginSucceeded(
                    userID: session.userID,
                    isOnboardingCompleted: true
                )
            )
        )
        await store.finish()
        XCTAssertTrue(sent.value.isEmpty)
    }

    func test_로딩중_재탭_무시() async {
        let loginCount = LockIsolated(0)
        let session = self.session
        let store = TestStore(
            initialState: AuthFeature.State(isLoading: true, loadingProvider: .apple)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.login = { _ in
                loginCount.withValue { $0 += 1 }
                return AuthBootstrap(session: session, isOnboardingCompleted: true, isNewMember: false)
            }
        }

        await store.send(.loginButtonTapped(.google))
        XCTAssertEqual(loginCount.value, 0)
    }

    func test_약관_링크_presentedTerms() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        }

        await store.send(.termsLinkTapped(.service)) {
            $0.presentedTerms = .service
        }
        await store.send(.dismissTerms) {
            $0.presentedTerms = nil
        }
        await store.send(.termsLinkTapped(.privacy)) {
            $0.presentedTerms = .privacy
        }
    }

    private enum AuthBootstrapFixtures {
        static func fixtureNewMember(session: AuthSession) -> AuthBootstrap {
            AuthBootstrap(
                session: session,
                isOnboardingCompleted: true,
                isNewMember: true
            )
        }

        static func fixtureExistingMember(session: AuthSession) -> AuthBootstrap {
            AuthBootstrap(
                session: session,
                isOnboardingCompleted: true,
                isNewMember: false
            )
        }
    }

    private func assertLoginSuccess(
        provider: AuthProvider,
        isOnboardingCompleted: Bool = true
    ) async {
        let requested = LockIsolated<AuthProvider?>(nil)
        let session = self.session
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.authClient.login = { value in
                requested.setValue(value)
                return AuthBootstrap(
                    session: session,
                    isOnboardingCompleted: isOnboardingCompleted,
                    isNewMember: false
                )
            }
        }

        await store.send(.loginButtonTapped(provider)) {
            $0.isLoading = true
            $0.loadingProvider = provider
            $0.toast = nil
        }
        await store.receive(\.loginResponse.success) {
            $0.isLoading = false
            $0.loadingProvider = nil
        }
        await store.receive(
            .delegate(
                .loginSucceeded(
                    userID: session.userID,
                    isOnboardingCompleted: isOnboardingCompleted
                )
            )
        )
        await store.finish()
        XCTAssertEqual(requested.value, provider)
    }

    private func assertLoginFailure(
        error: AuthError,
        expectedMessage: String
    ) async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.login = { _ in throw error }
        }

        await store.send(.loginButtonTapped(.apple)) {
            $0.isLoading = true
            $0.loadingProvider = .apple
            $0.toast = nil
        }
        await store.receive(\.loginResponse.failure) {
            $0.isLoading = false
            $0.loadingProvider = nil
            $0.toast = .error(expectedMessage)
        }
    }
}

private enum AnalyticsCall: Equatable {
    case identify(String)
    case markSignedUp
    case track(AnalyticsEvent)
    case reset
}

@MainActor
final class AuthFeatureIdentityTests: XCTestCase {
    private let session = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_신규_회원으로_로그인하면_사람을_먼저_묶고_가입일과_첫로그인이_뒤따른다() async {
        let calls = LockIsolated<[AnalyticsCall]>([])
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient.identify = { userID in
                calls.withValue { $0.append(.identify(userID)) }
            }
            $0.analyticsClient.markSignedUp = { _ in
                calls.withValue { $0.append(.markSignedUp) }
            }
            $0.analyticsClient.track = { event in
                calls.withValue { $0.append(.track(event)) }
            }
        }

        await store.send(
            .loginResponse(
                .success(
                    AuthBootstrap(
                        session: session,
                        isOnboardingCompleted: true,
                        isNewMember: true
                    )
                )
            )
        )
        await store.receive(
            .delegate(
                .loginSucceeded(
                    userID: session.userID,
                    isOnboardingCompleted: true
                )
            )
        )
        await store.finish()

        XCTAssertEqual(
            calls.value,
            [.identify("1"), .markSignedUp, .track(.loginStarted)]
        )
    }

    func test_기존_회원으로_로그인하면_사람만_묶고_가입일은_안_적는다() async {
        let calls = LockIsolated<[AnalyticsCall]>([])
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient.identify = { userID in
                calls.withValue { $0.append(.identify(userID)) }
            }
            $0.analyticsClient.markSignedUp = { _ in
                calls.withValue { $0.append(.markSignedUp) }
            }
            $0.analyticsClient.track = { event in
                calls.withValue { $0.append(.track(event)) }
            }
        }

        await store.send(
            .loginResponse(
                .success(
                    AuthBootstrap(
                        session: session,
                        isOnboardingCompleted: true,
                        isNewMember: false
                    )
                )
            )
        )
        await store.receive(
            .delegate(
                .loginSucceeded(
                    userID: session.userID,
                    isOnboardingCompleted: true
                )
            )
        )
        await store.finish()

        XCTAssertEqual(calls.value, [.identify("1")])
    }
}
