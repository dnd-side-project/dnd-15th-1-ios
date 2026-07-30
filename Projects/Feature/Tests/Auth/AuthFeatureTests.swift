import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class AuthFeatureTests: XCTestCase {
    func test_로그인성공_델리게이트_전달() async {
        let user = AuthUser(id: "1")
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signIn = { user }
        }

        await store.send(.loginButtonTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.signInResponse) {
            $0.isLoading = false
        }
        await store.receive(\.delegate.signInSucceeded)
    }
}
