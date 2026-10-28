import CoreLocation
import Foundation
import XCTest

@testable import Data

final class LocationUpdatePolicyTests: XCTestCase {

    // MARK: - 갱신을 켤지

    func test_사용중_허용이고_정확한_위치면_갱신한다() {
        XCTAssertTrue(
            LocationUpdatePolicy.canTrack(status: .authorizedWhenInUse, accuracy: .fullAccuracy)
        )
        XCTAssertTrue(
            LocationUpdatePolicy.canTrack(status: .authorizedAlways, accuracy: .fullAccuracy)
        )
    }

    func test_대략적_위치면_갱신하지_않는다() {
        XCTAssertFalse(
            LocationUpdatePolicy.canTrack(status: .authorizedWhenInUse, accuracy: .reducedAccuracy)
        )
    }

    func test_권한이_정해지지_않았으면_갱신하지_않는다() {
        XCTAssertFalse(
            LocationUpdatePolicy.canTrack(status: .notDetermined, accuracy: .fullAccuracy)
        )
    }

    func test_거부나_제한이면_갱신하지_않는다() {
        XCTAssertFalse(
            LocationUpdatePolicy.canTrack(status: .denied, accuracy: .fullAccuracy)
        )
        XCTAssertFalse(
            LocationUpdatePolicy.canTrack(status: .restricted, accuracy: .fullAccuracy)
        )
    }

    // MARK: - 좌표를 받을지

    func test_10초_안의_좌표는_받는다() {
        XCTAssertTrue(
            LocationUpdatePolicy.accepts(horizontalAccuracy: 5, age: 10, maxAge: .seconds(10))
        )
    }

    func test_10초보다_오래된_좌표는_버린다() {
        XCTAssertFalse(
            LocationUpdatePolicy.accepts(horizontalAccuracy: 5, age: 10.5, maxAge: .seconds(10))
        )
    }

    func test_오차가_음수인_좌표는_버린다() {
        XCTAssertFalse(
            LocationUpdatePolicy.accepts(horizontalAccuracy: -1, age: 0, maxAge: .seconds(10))
        )
    }
}
