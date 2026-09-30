import Domain
import SharedUtils
import XCTest

final class PlaceIDTests: XCTestCase {

    func test_장소_번호가_있으면_그것이_id다() {
        XCTAssertEqual(place(placeID: "42", kakaoPlaceID: "998877").id, "42")
    }

    func test_장소_번호가_없으면_카카오_번호가_id다() {
        XCTAssertEqual(place(placeID: nil, kakaoPlaceID: "998877").id, "998877")
    }

    func test_둘_다_없으면_이름과_좌표로_만든다() {
        XCTAssertEqual(place(placeID: nil, kakaoPlaceID: nil).id, "성수 카페|37.5|127.0")
    }

    private func place(placeID: String?, kakaoPlaceID: String?) -> Place {
        Place(
            placeID: placeID,
            kakaoPlaceID: kakaoPlaceID,
            name: "성수 카페",
            category: .cafe,
            address: "서울 성동구 성수동",
            roadAddress: nil,
            coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
            bookmarkCount: nil,
            thumbnailURLs: []
        )
    }
}
