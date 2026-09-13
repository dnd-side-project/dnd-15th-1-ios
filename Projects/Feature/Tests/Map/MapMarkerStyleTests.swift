import CoreKakaoMap
import Domain
@testable import Feature
import XCTest

@MainActor
final class MapMarkerStyleTests: XCTestCase {
    func test_마커이미지는_배율2로_구워진다() {
        let kinds: [MapMarker.Kind] = [
            .place,
            .numbered(1),
            .category(.cafe),
            .selected,
            .candidate,
        ]

        for kind in kinds {
            XCTAssertEqual(
                MapMarkerStyle.image(for: kind).scale,
                2,
                "\(kind) 마커는 SDK 보정을 상쇄하려고 배율 2로 구워야 한다"
            )
        }
    }
}
