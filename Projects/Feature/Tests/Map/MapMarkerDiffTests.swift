import Domain
@testable import Feature
import XCTest

final class MapMarkerDiffTests: XCTestCase {

    private let cafe = Coordinate(latitude: 37.3, longitude: 126.9)
    private let food = Coordinate(latitude: 37.4, longitude: 127.0)

    private func marker(
        id: String,
        coordinate: Coordinate? = nil,
        kind: MapMarker.Kind = .category(.cafe)
    ) -> MapMarker {
        MapMarker(id: id, coordinate: coordinate ?? cafe, kind: kind)
    }

    func test_같은_배열이면_아무_것도_안_바뀐다() {
        let pins = [marker(id: "1"), marker(id: "2")]
        let change = MapMarkerDiff.change(from: pins, to: pins)
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_선택핀만_더하면_그것만_added_다() {
        let category = marker(id: "1")
        let selected = marker(id: "map.selected", kind: .selected)
        let change = MapMarkerDiff.change(from: [category], to: [category, selected])
        XCTAssertEqual(change.added, [selected])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_선택핀만_빼면_그_id_만_removed_다() {
        let category = marker(id: "1")
        let selected = marker(id: "map.selected", kind: .selected)
        let change = MapMarkerDiff.change(from: [category, selected], to: [category])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, ["map.selected"])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_같은_id_좌표만_바뀌면_moved_다() {
        let before = marker(id: "map.selected", coordinate: cafe, kind: .selected)
        let after = marker(id: "map.selected", coordinate: food, kind: .selected)
        let change = MapMarkerDiff.change(from: [before], to: [after])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [after])
        XCTAssertEqual(change.restyled, [])
    }

    func test_같은_id_종류만_바뀌면_restyled_다() {
        let before = marker(id: "1", kind: .category(.cafe))
        let after = marker(id: "1", kind: .candidate)
        let change = MapMarkerDiff.change(from: [before], to: [after])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [after])
    }

    func test_빈_applied_면_desired_가_전부_added_다() {
        let pins = [marker(id: "1"), marker(id: "2")]
        let change = MapMarkerDiff.change(from: [], to: pins)
        XCTAssertEqual(change.added, pins)
        XCTAssertEqual(change.removedIDs, [])
    }
}
