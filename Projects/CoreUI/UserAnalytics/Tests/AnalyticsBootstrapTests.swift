@testable import CoreUserAnalytics
import XCTest

final class AnalyticsBootstrapTests: XCTestCase {
    func test_빈_프로젝트ID는_비활성으로_판정된다() {
        XCTAssertFalse(AnalyticsBootstrap.isEnabled(projectID: ""))
    }

    func test_공백만_있는_프로젝트ID도_비활성으로_판정된다() {
        XCTAssertFalse(AnalyticsBootstrap.isEnabled(projectID: "   "))
    }

    func test_값이_있으면_활성으로_판정된다() {
        XCTAssertTrue(AnalyticsBootstrap.isEnabled(projectID: "abcd1234"))
    }
}
