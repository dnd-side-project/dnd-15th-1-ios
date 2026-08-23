import Domain
import Foundation
import XCTest

@testable import Data

final class PlaceDTOMapperTests: XCTestCase {

    private func detailDTO(
        placeId: Int? = 42,
        categoryCode: String? = "CAFE",
        categoryName: String = "카페",
        ownershipStatus: String? = "MINE",
        savedByMe: Bool = true,
        savedMemberCount: Int = 12
    ) -> PlaceDetailResponseDTO {
        PlaceDetailResponseDTO(
            placeId: placeId,
            kakaoPlaceId: "998877",
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: "서울 성동구 아차산로 1",
            latitude: 37.5,
            longitude: 127.0,
            category: nil,
            categoryCode: categoryCode,
            categoryName: categoryName,
            phone: "02-000-0000",
            kakaoPlaceUrl: "https://place.map.kakao.com/998877",
            savedByMe: savedByMe,
            ownershipStatus: ownershipStatus,
            thumbnailUrl: nil,
            imageUrls: ["https://example.com/a.jpg"],
            savedMemberCount: savedMemberCount
        )
    }

    private func searchItemDTO(
        placeId: Int? = 42,
        kakaoPlaceId: String? = "998877",
        categoryCode: String? = "CAFE",
        categoryName: String = "카페"
    ) -> PlaceSearchItemDTO {
        PlaceSearchItemDTO(
            placeId: placeId,
            kakaoPlaceId: kakaoPlaceId,
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: "서울 성동구 아차산로 1",
            latitude: 37.5,
            longitude: 127.0,
            categoryCode: categoryCode,
            categoryName: categoryName,
            thumbnailUrl: nil,
            imageUrls: ["https://example.com/a.jpg"]
        )
    }

    private func savedPlaceDTO(
        categoryName: String = "카페"
    ) -> SavedPlaceResponseDTO {
        SavedPlaceResponseDTO(
            memberId: 1,
            placeId: 42,
            kakaoPlaceId: "998877",
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: "서울 성동구 아차산로 1",
            latitude: 37.5,
            longitude: 127.0,
            category: categoryName,
            categoryName: categoryName,
            ownershipStatus: "MINE",
            alias: nil,
            savedAt: "2026-08-17T01:27:55.129814",
            thumbnailUrl: nil,
            imageUrls: ["https://example.com/a.jpg"]
        )
    }

    func test_savedMemberCount가_bookmarkCount로_간다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(savedMemberCount: 12))
        XCTAssertEqual(detail.savedMemberCount, 12)
        XCTAssertEqual(detail.place.bookmarkCount, 12)
    }

    func test_ownershipStatus가_nil이면_ownership도_nil이다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(ownershipStatus: nil))
        XCTAssertNil(detail.ownership)
    }

    func test_ownershipStatus가_있으면_소문자로_매핑한다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(ownershipStatus: "PARTNER"))
        XCTAssertEqual(detail.ownership, .partner)
    }

    func test_placeId가_있으면_그것이_Place_id다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(placeId: 42))
        XCTAssertEqual(detail.place.id, "42")
    }

    func test_placeId가_nil이면_kakaoPlaceId가_Place_id다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(placeId: nil))
        XCTAssertEqual(detail.place.id, "998877")
    }

    func test_categoryCode가_있으면_코드로_매핑한다() {
        // 코드와 한글이 어긋나게 두고 코드가 이기는지 본다
        let detail = PlaceDTOMapper.toDomain(
            detailDTO(categoryCode: "SHOPPING", categoryName: "카페")
        )
        XCTAssertEqual(detail.place.category, .shopping)
    }

    func test_categoryCode가_nil이면_한글_이름으로_매핑한다() {
        let detail = PlaceDTOMapper.toDomain(
            detailDTO(categoryCode: nil, categoryName: "숙박")
        )
        XCTAssertEqual(detail.place.category, .accommodation)
    }

    func test_RESTAURANT는_food다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(categoryCode: "RESTAURANT"))
        XCTAssertEqual(detail.place.category, .food)
    }

    func test_모르는_코드는_한글_이름으로_넘어간다() {
        let detail = PlaceDTOMapper.toDomain(
            detailDTO(categoryCode: "SPACE_STATION", categoryName: "관광")
        )
        XCTAssertEqual(detail.place.category, .tourism)
    }

    func test_검색_항목의_categoryCode가_있으면_코드로_매핑한다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(
                places: [searchItemDTO(categoryCode: "SHOPPING", categoryName: "카페")],
                hasNext: false
            ),
            page: 0
        )
        XCTAssertEqual(page.items.first?.category, .shopping)
    }

    func test_저장_목록은_categoryCode가_없어_한글로_매핑한다() {
        let saved = PlaceDTOMapper.toDomain(savedPlaceDTO(categoryName: "숙박"))
        XCTAssertEqual(saved.place.category, .accommodation)
    }

    func test_검색_항목의_placeId가_nil이면_kakaoPlaceId가_Place_id다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(
                places: [searchItemDTO(placeId: nil, kakaoPlaceId: "998877")],
                hasNext: false
            ),
            page: 0
        )
        XCTAssertEqual(page.items.first?.id, "998877")
    }

    func test_page가_43이고_hasNext가_참이면_결과도_참이다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: true),
            page: 43
        )
        XCTAssertTrue(page.hasNext)
    }

    func test_page가_44이고_hasNext가_참이어도_결과는_거짓이다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: true),
            page: 44
        )
        XCTAssertFalse(page.hasNext)
    }

    func test_page가_0이고_hasNext가_거짓이면_결과도_거짓이다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: false),
            page: 0
        )
        XCTAssertFalse(page.hasNext)
    }
}
