import Domain
import Foundation
import XCTest

@testable import Data

final class ContentDTOMapperTests: XCTestCase {

    func test_게시글_속_장소_사진은_대표_사진이_맨_앞이다() throws {
        let detail = ContentDTOMapper.toDetail(detailDTO(thumbnailUrl: "https://example.com/t.jpg"))

        let place = try XCTUnwrap(detail.places.first)
        XCTAssertEqual(place.place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
    }

    func test_게시글_속_장소_카테고리는_장소_변환표를_쓴다() throws {
        let detail = ContentDTOMapper.toDetail(detailDTO(categoryName: "생활 편의"))

        XCTAssertEqual(try XCTUnwrap(detail.places.first).place.category, .convenience)
    }

    func test_게시글_속_장소는_장소_번호와_저장_여부를_옮기고_저장_수는_모른다() throws {
        let place = try XCTUnwrap(ContentDTOMapper.toDetail(detailDTO()).places.first)

        XCTAssertEqual(place.place.placeID, "101")
        XCTAssertEqual(place.place.kakaoPlaceID, "k101")
        XCTAssertTrue(place.isSaved)
        XCTAssertNil(place.place.bookmarkCount)
        XCTAssertNil(place.place.roadAddress)
    }

    // 서버가 도로명 없음을 "" 로 주는 응답이 있다. nil 과 같게 읽혀야 CandidateRow 의 주소 힌트 대체가 산다
    func test_게시글_속_장소_도로명_빈_문자열은_nil이다() throws {
        let place = try XCTUnwrap(ContentDTOMapper.toDetail(detailDTO(roadAddress: "")).places.first)

        XCTAssertNil(place.place.roadAddress)
    }

    func test_게시글_속_장소에_지번_주소가_없으면_읽기에_실패한다() {
        let json = Data("""
        {
          "placeId": 101,
          "name": "가게",
          "roadAddress": "서울 성동구 아차산로 1",
          "categoryName": "카페",
          "latitude": 37.5,
          "longitude": 127.0,
          "savedByMe": false
        }
        """.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(ContentDetailPlaceResponseDTO.self, from: json))
    }

    func test_목록_응답의_인기_태그는_피드에_담긴다() {
        let feed = ContentDTOMapper.toFeed(
            ContentPageResponseDTO(contents: [], hasNext: true, popularTags: ["성수", "강남"])
        )

        XCTAssertEqual(feed.popularTags, ["성수", "강남"])
        XCTAssertTrue(feed.page.hasNext)
    }

    func test_인기_태그가_없으면_빈_목록이다() {
        let feed = ContentDTOMapper.toFeed(
            ContentPageResponseDTO(contents: [], hasNext: false, popularTags: nil)
        )

        XCTAssertEqual(feed.popularTags, [])
    }

    func test_정렬_기준을_서버_쿼리_값으로_바꾼다() {
        XCTAssertEqual(ContentDTOMapper.toQuery(.popular), "POPULAR")
        XCTAssertEqual(ContentDTOMapper.toQuery(.preference), "PREFERENCE")
        XCTAssertEqual(
            ContentEndpoint.contents(sort: .preference, page: 0, size: 10).queryItems.first,
            URLQueryItem(name: "sort", value: "PREFERENCE")
        )
    }

    private func detailDTO(
        categoryName: String = "카페",
        thumbnailUrl: String? = nil,
        roadAddress: String? = nil
    ) -> ContentDetailResponseDTO {
        ContentDetailResponseDTO(
            contentId: 1,
            title: "제목",
            caption: nil,
            canonicalUrl: nil,
            places: [
                ContentDetailPlaceResponseDTO(
                    placeId: 101,
                    kakaoPlaceId: "k101",
                    name: "가게",
                    address: "서울 성동구 성수동",
                    roadAddress: roadAddress,
                    categoryName: categoryName,
                    latitude: 37.5,
                    longitude: 127.0,
                    savedByMe: true,
                    thumbnailUrl: thumbnailUrl,
                    imageUrls: ["https://example.com/a.jpg"]
                ),
            ]
        )
    }
}
