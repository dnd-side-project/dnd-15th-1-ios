import CoreNetwork
import CoreSocialAuth
import Domain
import XCTest

@testable import Data

final class AuthErrorMapperTests: XCTestCase {
    func test_취소_에러를_cancelled로_매핑한다() {
        let mapped = AuthErrorMapper.map(SocialAuthError.cancelled, isLoginPath: true)

        XCTAssertEqual(mapped, .cancelled)
    }

func test_전송_에러를_network로_매핑한다() {
        let mapped = AuthErrorMapper.map(
            NetworkError.transport(message: "offline"),
            isLoginPath: false
        )

        XCTAssertEqual(mapped, .network)
    }

    func test_인증_실패를_unauthorized로_매핑한다() {
        let mapped = AuthErrorMapper.map(NetworkError.unauthorized, isLoginPath: false)

        XCTAssertEqual(mapped, .unauthorized)
    }

func test_로그인_경로_badRequest를_loginFailed로_매핑한다() {
        let mapped = AuthErrorMapper.map(
            NetworkError.badRequest(message: "invalid"),
            isLoginPath: true
        )

        XCTAssertEqual(mapped, .loginFailed)
    }
}
