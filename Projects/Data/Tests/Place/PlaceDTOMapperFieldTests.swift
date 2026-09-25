import Domain
import Foundation
import XCTest

@testable import Data

final class PlaceDTOMapperFieldTests: XCTestCase {

    func test_카테고리_코드가_있으면_코드를_먼저_본다() {
        XCTAssertEqual(PlaceDTOMapper.category(code: "SHOPPING", name: "카페"), .shopping)
    }

    func test_모르는_코드면_한글_이름을_본다() {
        XCTAssertEqual(PlaceDTOMapper.category(code: "SPACE_STATION", name: "관광"), .tourism)
    }

    func test_코드와_이름을_모두_모르면_food다() {
        XCTAssertEqual(PlaceDTOMapper.category(code: nil, name: nil), .food)
        XCTAssertEqual(PlaceDTOMapper.category(code: nil, name: "맛집"), .food)
    }

    func test_편의와_생활_편의는_convenience다() {
        XCTAssertEqual(PlaceDTOMapper.category(code: nil, name: "편의"), .convenience)
        XCTAssertEqual(PlaceDTOMapper.category(code: nil, name: "생활 편의"), .convenience)
    }

    func test_저장_관계는_대소문자를_가리지_않는다() {
        XCTAssertEqual(PlaceDTOMapper.ownership("MINE"), .mine)
        XCTAssertEqual(PlaceDTOMapper.ownership("partner"), .partner)
        XCTAssertEqual(PlaceDTOMapper.ownership("Together"), .together)
    }

    func test_모르는_저장_관계는_nil이다() {
        XCTAssertNil(PlaceDTOMapper.ownership("UNKNOWN"))
    }

    func test_사진은_대표_사진이_맨_앞이고_나머지가_뒤따른다() {
        let urls = PlaceDTOMapper.photoURLs(
            thumbnailURL: "https://example.com/thumb.jpg",
            imageURLs: ["https://example.com/a.jpg", "https://example.com/b.jpg"]
        )

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://example.com/thumb.jpg",
            "https://example.com/a.jpg",
            "https://example.com/b.jpg",
        ])
    }

    func test_같은_사진_주소는_한_번만_넣는다() {
        let urls = PlaceDTOMapper.photoURLs(
            thumbnailURL: "https://example.com/a.jpg",
            imageURLs: [
                "https://example.com/a.jpg",
                "https://example.com/b.jpg",
                "https://example.com/b.jpg",
            ]
        )

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg",
        ])
    }

    func test_대표_사진이_없으면_나머지만_넣고_못_읽는_주소는_버린다() {
        let urls = PlaceDTOMapper.photoURLs(
            thumbnailURL: nil,
            imageURLs: ["https://example.com/a.jpg", ""]
        )

        XCTAssertEqual(urls.map(\.absoluteString), ["https://example.com/a.jpg"])
    }

    func test_저장_장소는_응답의_저장_수를_읽는다() {
        let saved = PlaceDTOMapper.toDomain(savedPlaceDTO(ownershipStatus: "MINE", savedMemberCount: 7))

        XCTAssertEqual(saved.place.bookmarkCount, 7)
    }

    func test_저장_장소의_모르는_저장_관계는_mine이다() {
        let saved = PlaceDTOMapper.toDomain(savedPlaceDTO(ownershipStatus: "???", savedMemberCount: 1))

        XCTAssertEqual(saved.ownership, .mine)
    }

    func test_저장_장소도_대표_사진이_맨_앞이다() {
        let saved = PlaceDTOMapper.toDomain(savedPlaceDTO(ownershipStatus: "MINE", savedMemberCount: 1))

        XCTAssertEqual(saved.place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/thumb.jpg",
            "https://example.com/a.jpg",
        ])
    }

    // 서버가 도로명 없음을 nil 대신 "" 로 주기도 한다. 매퍼가 빈 문자열도 nil 로 합친다 (2026-09-18 사용자 결정)
    func test_도로명_빈_문자열은_없음으로_본다() {
        let dto = SavedPlaceResponseDTO(
            memberId: 1,
            placeId: 42,
            kakaoPlaceId: "998877",
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: "",
            latitude: 37.5,
            longitude: 127.0,
            category: "카페",
            categoryName: "카페",
            ownershipStatus: "MINE",
            alias: nil,
            savedAt: "2026-08-17T01:27:55.129814",
            thumbnailUrl: nil,
            imageUrls: [],
            savedMemberCount: 0
        )

        XCTAssertNil(PlaceDTOMapper.toDomain(dto).place.roadAddress)
    }

    private func savedPlaceDTO(ownershipStatus: String, savedMemberCount: Int) -> SavedPlaceResponseDTO {
        SavedPlaceResponseDTO(
            memberId: 1,
            placeId: 42,
            kakaoPlaceId: "998877",
            name: "성수 카페",
            address: "서울 성동구 성수동",
            roadAddress: nil,
            latitude: 37.5,
            longitude: 127.0,
            category: "카페",
            categoryName: "카페",
            ownershipStatus: ownershipStatus,
            alias: nil,
            savedAt: "2026-08-17T01:27:55.129814",
            thumbnailUrl: "https://example.com/thumb.jpg",
            imageUrls: ["https://example.com/a.jpg"],
            savedMemberCount: savedMemberCount
        )
    }
}
