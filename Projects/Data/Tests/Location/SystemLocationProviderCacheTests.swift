import Foundation
import XCTest

@testable import Data

final class SystemLocationProviderCacheTests: XCTestCase {

    func test_캐시_1분이내면_사용() {
        XCTAssertTrue(
            SystemLocationProvider.isCacheFresh(age: 60, maxAge: .seconds(60))
        )
        XCTAssertTrue(
            SystemLocationProvider.isCacheFresh(age: 0, maxAge: .seconds(60))
        )
        XCTAssertTrue(
            SystemLocationProvider.isCacheFresh(age: 30, maxAge: .seconds(60))
        )
    }

    func test_캐시_1분초과면_미사용() {
        XCTAssertFalse(
            SystemLocationProvider.isCacheFresh(age: 61, maxAge: .seconds(60))
        )
        XCTAssertFalse(
            SystemLocationProvider.isCacheFresh(age: 120, maxAge: .seconds(60))
        )
    }

    func test_캐시_초보다_작은_단위도_비교() {
        XCTAssertTrue(
            SystemLocationProvider.isCacheFresh(age: 1.4, maxAge: .milliseconds(1500))
        )
        XCTAssertFalse(
            SystemLocationProvider.isCacheFresh(age: 1.6, maxAge: .milliseconds(1500))
        )
    }

    func test_캐시_나이가_음수면_미사용() {
        XCTAssertFalse(
            SystemLocationProvider.isCacheFresh(age: -1, maxAge: .seconds(60))
        )
    }
}
