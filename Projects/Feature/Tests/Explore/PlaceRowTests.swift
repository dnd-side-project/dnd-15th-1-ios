import Domain
@testable import Feature
import XCTest

@MainActor
final class PlaceRowTests: XCTestCase {
    func test_저장_수를_모르면_배지_글자가_없다() {
        XCTAssertNil(PlaceRow(place: .fixture(id: "1", bookmarkCount: nil)).badgeText)
    }

    func test_저장_수를_알면_배지에_그_수를_쓴다() {
        XCTAssertEqual(PlaceRow(place: .fixture(id: "1", bookmarkCount: 12)).badgeText, "12")
    }
}
