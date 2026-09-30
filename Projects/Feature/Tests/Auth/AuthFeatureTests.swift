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

    func test_로그인에_실패하면_로그인_실패_토스트를_띄운다() async {
        await assertLoginFailure(
            error: .loginFailed,
            expectedMessage: "로그인에 실패했습니다."
        )
    }

    func test_네트워크_오류로_실패하면_연결_확인_토스트를_띄운다() async {
        await assertLoginFailure(
            error: .network,
            expectedMessage: "네트워크 연결을 확인해 주세요."
        )
    }

    func test_알_수_없는_오류로_실패하면_재시도_안내_토스트를_띄운다() async {
        await assertLoginFailure(
            error: .unknown,
            expectedMessage: "잠시 후 다시 시도해 주세요."
        )
    }

    func test_인증_오류로_실패하면_재시도_안내_토스트를_띄운다() async {
        await assertLoginFailure(
            error: .unauthorized,
            expectedMessage: "잠시 후 다시 시도해 주세요."
        )
    }

    func test_로그인을_취소하면_토스트를_띄우지_않는다() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.login = { _ in throw AuthError.cancelled }
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
        XCTAssertNil(store.state.toast)
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

    func test_약관_링크를_누르면_그_약관을_띄우고_닫으면_내린다() async {
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

@MainActor
final class AuthFeatureIdentityTests: XCTestCase {
    private let session = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_신규_회원으로_로그인하면_사람을_먼저_묶고_가입일과_첫로그인이_뒤따른다() async {
        let analytics = AnalyticsRecorder()
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

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
        await store.finish()

        XCTAssertEqual(
            analytics.calls,
            [.identify("1"), .markSignedUp, .track(.loginStarted)]
        )
    }

    func test_기존_회원으로_로그인하면_사람만_묶고_가입일은_안_적는다() async {
        let analytics = AnalyticsRecorder()
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

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
        await store.finish()

        XCTAssertEqual(analytics.calls, [.identify("1")])
    }
}
