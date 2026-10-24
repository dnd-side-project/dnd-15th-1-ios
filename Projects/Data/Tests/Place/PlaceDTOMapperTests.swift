import Domain
import Foundation
import XCTest

@testable import Data

final class PlaceDTOMapperTests: XCTestCase {

    private func detailDTO(
        placeId: Int? = 42,
        categoryCode: String? = "CAFE",
        categoryName: String = "카페",
        roadAddress: String? = "서울 성동구 아차산로 1",
        ownershipStatus: String? = "MINE",
        savedByMe: Bool = true,
        savedMemberCount: Int = 12
    ) -> PlaceDetailResponseDTO {
        PlaceDetailResponseDTO(
            placeId: placeId,
            kakaoPlaceId: "998877",
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: roadAddress,
            latitude: 37.5,
            longitude: 127.0,
            category: nil,
            categoryCode: categoryCode,
            categoryName: categoryName,
            phone: "02-000-0000",
            kakaoPlaceUrl: "https://place.map.kakao.com/998877",
            savedByMe: savedByMe,
            ownershipStatus: ownershipStatus,
            thumbnailUrl: "https://example.com/t.jpg",
            imageUrls: ["https://example.com/a.jpg"],
            savedMemberCount: savedMemberCount
        )
    }

    private func searchItemDTO(
        placeId: Int? = 42,
        kakaoPlaceId: String? = "998877",
        categoryCode: String? = "CAFE",
        categoryName: String = "카페",
        roadAddress: String? = "서울 성동구 아차산로 1"
    ) -> PlaceSearchItemDTO {
        PlaceSearchItemDTO(
            placeId: placeId,
            kakaoPlaceId: kakaoPlaceId,
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: roadAddress,
            latitude: 37.5,
            longitude: 127.0,
            categoryCode: categoryCode,
            categoryName: categoryName,
            thumbnailUrl: "https://example.com/t.jpg",
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
            imageUrls: ["https://example.com/a.jpg"],
            savedMemberCount: 3
        )
    }

    func test_상세의_저장_수를_옮긴다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(savedMemberCount: 12))
        XCTAssertEqual(detail.place.bookmarkCount, 12)
    }

    func test_상세에_저장_관계가_없으면_nil이다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(ownershipStatus: nil))
        XCTAssertNil(detail.ownership)
    }

    func test_상세의_저장_관계를_옮긴다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(ownershipStatus: "PARTNER"))
        XCTAssertEqual(detail.ownership, .partner)
    }

    func test_상세의_장소_번호와_카카오_번호를_옮긴다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(placeId: 42))
        XCTAssertEqual(detail.place.placeID, "42")
        XCTAssertEqual(detail.place.kakaoPlaceID, "998877")
    }

    func test_상세에_장소_번호가_없으면_카카오_번호만_옮긴다() {
        let detail = PlaceDTOMapper.toDomain(detailDTO(placeId: nil))
        XCTAssertNil(detail.place.placeID)
        XCTAssertEqual(detail.place.kakaoPlaceID, "998877")
    }

    func test_상세의_카테고리와_사진을_옮기고_빈_도로명은_없음으로_읽는다() {
        // 코드와 한글이 어긋나게 두고 코드가 넘어가는지 본다. 값마다의 결과는 PlaceDTOMapperFieldTests 가 본다
        let place = PlaceDTOMapper.toDomain(
            detailDTO(categoryCode: "SHOPPING", categoryName: "카페", roadAddress: "")
        ).place
        XCTAssertEqual(place.category, .shopping)
        XCTAssertEqual(place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
        XCTAssertNil(place.roadAddress)
    }

    func test_검색_항목의_카테고리와_사진을_옮기고_빈_도로명은_없음으로_읽는다() throws {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(
                places: [searchItemDTO(categoryCode: "SHOPPING", categoryName: "카페", roadAddress: "")],
                hasNext: false
            ),
            page: 0
        )
        let place = try XCTUnwrap(page.items.first)
        XCTAssertEqual(place.category, .shopping)
        XCTAssertEqual(place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
        XCTAssertNil(place.roadAddress)
    }

    func test_저장_장소의_카테고리를_한글_이름으로_옮긴다() {
        let saved = PlaceDTOMapper.toDomain(savedPlaceDTO(categoryName: "숙박"))
        XCTAssertEqual(saved.place.category, .accommodation)
    }

    func test_검색_항목에_장소_번호가_없으면_카카오_번호만_옮긴다() throws {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(
                places: [searchItemDTO(placeId: nil, kakaoPlaceId: "998877")],
                hasNext: false
            ),
            page: 0
        )
        let place = try XCTUnwrap(page.items.first)
        XCTAssertNil(place.placeID)
        XCTAssertEqual(place.kakaoPlaceID, "998877")
    }

    func test_43페이지에서_다음이_있다고_하면_다음_페이지가_있다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: true),
            page: 43
        )
        XCTAssertTrue(page.hasNext)
    }

    func test_44페이지면_다음이_있다고_해도_다음_페이지가_없다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: true),
            page: 44
        )
        XCTAssertFalse(page.hasNext)
    }

    func test_다음이_없다고_하면_다음_페이지가_없다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: false),
            page: 0
        )
        XCTAssertFalse(page.hasNext)
    }

    func test_상세의_내_저장_여부를_옮긴다() {
        XCTAssertTrue(PlaceDTOMapper.toDomain(detailDTO(savedByMe: true)).isSaved)
    }

    func test_검색_항목은_저장_수를_모른다() {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO()], hasNext: false),
            page: 0
        )
        XCTAssertNil(page.items.first?.bookmarkCount)
    }

    func test_검색_항목에_두_번호가_없으면_둘_다_비어_있다() throws {
        let page = PlaceDTOMapper.toSearchPage(
            PlaceSearchResponseDTO(places: [searchItemDTO(placeId: nil, kakaoPlaceId: nil)], hasNext: false),
            page: 0
        )
        let place = try XCTUnwrap(page.items.first)
        XCTAssertNil(place.placeID)
        XCTAssertNil(place.kakaoPlaceID)
    }
}
