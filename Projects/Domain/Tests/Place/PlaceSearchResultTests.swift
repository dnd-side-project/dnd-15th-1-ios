import Domain
import SharedUtils
import XCTest

final class PlaceSearchResultTests: XCTestCase {

    func test_검색_결과의_id는_장소의_id다() {
        XCTAssertEqual(result(ownership: nil).id, "42")
    }

    func test_저장_목록의_한_줄을_옮기면_저장_관계와_별칭을_그대로_든다() {
        let saved = SavedPlace(
            place: place,
            ownership: .partner,
            alias: "우리 카페",
            memo: "메모",
            savedAt: Date(timeIntervalSince1970: 0)
        )

        let result = PlaceSearchResult(savedPlace: saved)

        XCTAssertEqual(result.place, place)
        XCTAssertEqual(result.ownership, .partner)
        XCTAssertEqual(result.alias, "우리 카페")
    }

    func test_누군가_저장한_결과는_메모와_저장_시각_없이_저장_목록의_한_줄이_된다() {
        XCTAssertEqual(
            result(ownership: .together, alias: "우리 카페").savedPlace,
            SavedPlace(place: place, ownership: .together, alias: "우리 카페", memo: nil, savedAt: nil)
        )
    }

    func test_아무도_저장하지_않은_결과는_저장_목록의_한_줄이_아니다() {
        XCTAssertNil(result(ownership: nil).savedPlace)
    }

    private let place = Place(
        placeID: "42",
        kakaoPlaceID: "998877",
        name: "성수 카페",
        category: .cafe,
        address: "서울 성동구 성수동",
        roadAddress: nil,
        coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
        bookmarkCount: nil,
        thumbnailURLs: []
    )

    private func result(ownership: PlaceOwnership?, alias: String? = nil) -> PlaceSearchResult {
        PlaceSearchResult(place: place, ownership: ownership, alias: alias)
    }
}
