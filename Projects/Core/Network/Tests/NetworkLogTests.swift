@testable import CoreNetwork
import XCTest

final class NetworkLogTests: XCTestCase {
    func test_redact_masks_snake_case_oauth_keys() {
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

    func test_redact_masks_form_encoded_tokens() {
        let input = "access_token=aaa&refresh_token=bbb&id_token=ccc"
        let redacted = NetworkLog.redact(input)
        XCTAssertEqual(
            redacted,
            "access_token=[REDACTED]&refresh_token=[REDACTED]&id_token=[REDACTED]"
        )
    }
}
