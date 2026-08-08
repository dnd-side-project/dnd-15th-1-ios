import CoreNetwork
import XCTest

final class NetworkJSONCodingTests: XCTestCase {
    func test_parseDate_supports_existing_and_iso8601_variants() {
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22.727Z"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22Z"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22.727+09:00"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22+09:00"))
        XCTAssertNil(NetworkJSONCoding.parseDate("not-a-date"))
    }

    func test_decoder_accepts_server_fractional_z() throws {
        struct Payload: Decodable {
            let lastRejoinedAt: Date
        }

        let json = Data(#"{"lastRejoinedAt":"2026-08-08T13:03:22.727Z"}"#.utf8)
        let payload = try NetworkJSONCoding.makeDecoder().decode(Payload.self, from: json)
        XCTAssertEqual(
            payload.lastRejoinedAt.timeIntervalSince1970,
            1786194202.727,
            accuracy: 0.001
        )
    }
}
