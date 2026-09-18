@testable import Feature
import Foundation
import XCTest

final class DateExtensionTests: XCTestCase {
    func test_지난_데이트_날짜는_서울_기준_두자리_연도로_보인다() {
        // 2026-08-16 00:00 Asia/Seoul
        XCTAssertEqual(Date(timeIntervalSince1970: 1_786_806_000).shortDateText, "26.08.16")
    }

    func test_UTC로는_전날이어도_서울_날짜로_보인다() {
        // 2026-08-05 15:30 UTC = 2026-08-06 00:30 Asia/Seoul
        XCTAssertEqual(Date(timeIntervalSince1970: 1_785_943_800).shortDateText, "26.08.06")
    }
}
