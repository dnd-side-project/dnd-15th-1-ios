@testable import CoreUserAnalytics
import XCTest

final class AnalyticsValueMixpanelMappingTests: XCTestCase {
    func test_참거짓은_글자가_아니라_참거짓으로_넘어간다() {
        let value = AnalyticsValue.bool(true).mixpanelProperty
        XCTAssertTrue(value is Bool)
        XCTAssertEqual(value as? Bool, true)
        XCTAssertFalse(value is String)
    }

    func test_정수는_글자가_아니라_숫자로_넘어간다() {
        let value = AnalyticsValue.int(3).mixpanelProperty
        XCTAssertTrue(value is Int)
        XCTAssertEqual(value as? Int, 3)
        XCTAssertFalse(value is String)
    }

    func test_글자는_글자_그대로_넘어간다() {
        let value = AnalyticsValue.string("share").mixpanelProperty
        XCTAssertEqual(value as? String, "share")
    }
}
