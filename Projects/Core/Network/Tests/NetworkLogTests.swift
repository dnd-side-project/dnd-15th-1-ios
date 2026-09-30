@testable import CoreNetwork
import XCTest

final class NetworkLogTests: XCTestCase {
    func test_JSON_본문의_토큰_값을_가린다() {
        let input = """
        {"access_token":"aaa","refresh_token":"bbb","id_token":"ccc","accessToken":"ddd"}
        """
        let redacted = NetworkLog.redact(input)
        XCTAssertFalse(redacted.contains("aaa"))
        XCTAssertFalse(redacted.contains("bbb"))
        XCTAssertFalse(redacted.contains("ccc"))
        XCTAssertFalse(redacted.contains("ddd"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func test_폼_본문의_토큰_값을_가린다() {
        let input = "access_token=aaa&refresh_token=bbb&id_token=ccc"
        let redacted = NetworkLog.redact(input)
        XCTAssertEqual(
            redacted,
            "access_token=[REDACTED]&refresh_token=[REDACTED]&id_token=[REDACTED]"
        )
    }

    func test_로그에_남기는_주소는_경로만_남긴다() {
        let url = URL(string: "https://dulpick.omong.kr/api/v1/auth/reissue?token=secret#frag")
        XCTAssertEqual(
            NetworkLog.sanitizedURLString(url),
            "/api/v1/auth/reissue"
        )
    }
}
