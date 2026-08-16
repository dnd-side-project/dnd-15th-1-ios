import Feature
import XCTest

final class DeepLinkRouterTests: XCTestCase {
    func test_홈_커스텀스킴_파싱() {
        guard let url = URL(string: "dulpick://home") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        XCTAssertEqual(DeepLinkRouter.parse(url), .home)
    }

    func test_지도_경로_파싱() {
        guard let url = URL(string: "https://dulpick.app/map") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        XCTAssertEqual(DeepLinkRouter.parse(url), .map)
    }

    func test_프로필경로_마이페이지_호환파싱() {
        guard let url = URL(string: "https://dulpick.app/profile") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        XCTAssertEqual(DeepLinkRouter.parse(url), .myPage)
    }

    func test_로그인경로_파싱() {
        guard let url = URL(string: "dulpick://auth/sign-in") else {
            return XCTFail("유효한 URL을 만들지 못했습니다.")
        }
        XCTAssertEqual(DeepLinkRouter.parse(url), .signIn)
    }
}
