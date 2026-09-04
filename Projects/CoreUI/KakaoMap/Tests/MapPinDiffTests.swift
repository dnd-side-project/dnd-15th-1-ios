@testable import CoreKakaoMap
import SharedUtils
import UIKit
import XCTest

final class MapPinDiffTests: XCTestCase {

    private func pin(
        _ id: String,
        lat: Double = 37.5,
        lng: Double = 127.0,
        style: String = "a",
        rank: Int = 0
    ) -> MapPin {
        MapPin(
            id: id,
            coordinate: Coordinate(latitude: lat, longitude: lng),
            styleID: style,
            rank: rank,
            makeStyle: { MapPinStyle(image: UIImage(), anchorPoint: .zero) }
        )
    }

    func test_같은_배열이면_아무_것도_안_바뀐다() {
        let pins = [pin("1"), pin("2")]
        let change = MapPinDiff.change(from: pins, to: pins)
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_선택핀만_더하면_그것만_added_다() {
        let category = pin("1")
        let selected = pin("map.selected", style: "selected")
        let change = MapPinDiff.change(from: [category], to: [category, selected])
        XCTAssertEqual(change.added, [selected])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_선택핀만_빼면_그_id_만_removed_다() {
        let category = pin("1")
        let selected = pin("map.selected", style: "selected")
        let change = MapPinDiff.change(from: [category, selected], to: [category])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, ["map.selected"])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [])
    }

    func test_같은_id_좌표만_바뀌면_moved_다() {
        let before = pin("map.selected", lat: 37.3, lng: 126.9, style: "selected")
        let after = pin("map.selected", lat: 37.4, lng: 127.0, style: "selected")
        let change = MapPinDiff.change(from: [before], to: [after])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [after])
        XCTAssertEqual(change.restyled, [])
    }

    func test_같은_id_종류만_바뀌면_restyled_다() {
        let before = pin("1", style: "category.cafe")
        let after = pin("1", style: "candidate")
        let change = MapPinDiff.change(from: [before], to: [after])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [after])
    }

    func test_빈_applied_면_desired_가_전부_added_다() {
        let pins = [pin("1"), pin("2")]
        let change = MapPinDiff.change(from: [], to: pins)
        XCTAssertEqual(change.added, pins)
        XCTAssertEqual(change.removedIDs, [])
    }

    func test_같은_id_순위만_바뀌면_restyled_다() {
        let before = pin("1", style: "a", rank: 0)
        let after = pin("1", style: "a", rank: 1)
        let change = MapPinDiff.change(from: [before], to: [after])
        XCTAssertEqual(change.added, [])
        XCTAssertEqual(change.removedIDs, [])
        XCTAssertEqual(change.moved, [])
        XCTAssertEqual(change.restyled, [after])
    }
}
