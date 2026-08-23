import CoreNetwork
import Foundation
import XCTest

@testable import Data

final class PlaceEndpointTests: XCTestCase {

    func test_장소_상세는_placeID를_경로에_넣는다() {
        let endpoint = PlaceEndpoint.detail(placeID: 42)
        XCTAssertEqual(endpoint.path, "/api/v1/places/42")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        XCTAssertNil(endpoint.body)
    }

    func test_카카오_상세는_query를_반드시_싣는다() {
        let endpoint = PlaceEndpoint.kakaoDetail(kakaoPlaceID: "12345", query: "성수 카페")
        XCTAssertEqual(endpoint.path, "/api/v1/places/kakao/12345")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.queryItems, [URLQueryItem(name: "query", value: "성수 카페")])
        XCTAssertNil(endpoint.body)
    }

    func test_별칭_수정은_PATCH이고_body에_alias를_담는다() throws {
        let endpoint = PlaceEndpoint.updateAlias(placeID: 7, alias: "우리 카페")
        XCTAssertEqual(endpoint.path, "/api/v1/places/7/alias")
        XCTAssertEqual(endpoint.method, .patch)
        XCTAssertTrue(endpoint.queryItems.isEmpty)

        let body = try XCTUnwrap(endpoint.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["alias"] as? String, "우리 카페")
    }

    func test_별칭이_nil이면_body에_null로_실린다() throws {
        let endpoint = PlaceEndpoint.updateAlias(placeID: 7, alias: nil)
        let body = try XCTUnwrap(endpoint.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertTrue(json.keys.contains("alias"))
        XCTAssertTrue(json["alias"] is NSNull)
    }

    func test_검색은_query_page_size_셋을_싣는다() {
        let endpoint = PlaceEndpoint.search(query: "성수", page: 2, size: 10)
        XCTAssertEqual(endpoint.path, "/api/v1/places/search")
        XCTAssertEqual(endpoint.queryItems, [
            URLQueryItem(name: "query", value: "성수"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "size", value: "10"),
        ])
    }

    func test_기존_case_셋의_경로는_그대로다() {
        XCTAssertEqual(PlaceEndpoint.savedPlaces.path, "/api/v1/places")
        XCTAssertEqual(PlaceEndpoint.save(kakaoPlaceID: "1", query: "a", alias: nil).path, "/api/v1/places")
        XCTAssertEqual(PlaceEndpoint.remove(placeID: "9").path, "/api/v1/places/9")
    }
}
