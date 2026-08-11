import Domain
import Feature
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
                return AuthBootstrap(session: session, isOnboardingCompleted: true)
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

    private func assertLoginSuccess(provider: AuthProvider) async {
        let requested = LockIsolated<AuthProvider?>(nil)
        let session = self.session
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.login = { value in
                requested.setValue(value)
                return AuthBootstrap(session: session, isOnboardingCompleted: true)
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
        await store.receive(\.delegate.loginSucceeded)
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
