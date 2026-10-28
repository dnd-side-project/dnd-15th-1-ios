@testable import Feature
import XCTest

final class PlaceMapLinkTests: XCTestCase {
    private let bundleID = "com.dulpick.debug"

    func test_네이버는_앱과_웹_모두_이름으로_찾는다() throws {
        let link = try XCTUnwrap(
            PlaceMapLink.make(
                app: .naver,
                name: "성수 카페",
                kakaoPlaceID: "26338954",
                kakaoPlaceURL: nil,
                bundleID: bundleID
            )
        )

        XCTAssertEqual(
            link.appURL.absoluteString,
            "nmap://search?query=%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98&appname=com.dulpick.debug"
        )
        XCTAssertEqual(
            link.webURL.absoluteString,
            "https://m.map.naver.com/search?query=%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98"
        )
    }

    func test_카카오_번호가_있으면_카카오는_장소_화면을_연다() throws {
        let link = try XCTUnwrap(
            PlaceMapLink.make(
                app: .kakao,
                name: "성수 카페",
                kakaoPlaceID: "26338954",
                kakaoPlaceURL: nil,
                bundleID: bundleID
            )
        )

        XCTAssertEqual(link.appURL.absoluteString, "kakaomap://place?id=26338954")
        XCTAssertEqual(link.webURL.absoluteString, "https://place.map.kakao.com/26338954")
    }

    func test_카카오_번호가_있으면_서버가_준_웹_주소가_먼저다() throws {
        let serverURL = try XCTUnwrap(URL(string: "https://place.map.kakao.com/26338954?from=server"))
        let link = try XCTUnwrap(
            PlaceMapLink.make(
                app: .kakao,
                name: "성수 카페",
                kakaoPlaceID: "26338954",
                kakaoPlaceURL: serverURL,
                bundleID: bundleID
            )
        )

        XCTAssertEqual(link.webURL, serverURL)
    }

    func test_카카오_번호가_없으면_카카오도_이름으로_찾는다() throws {
        let serverURL = try XCTUnwrap(URL(string: "https://place.map.kakao.com/26338954"))
        let link = try XCTUnwrap(
            PlaceMapLink.make(
                app: .kakao,
                name: "성수 카페",
                kakaoPlaceID: nil,
                kakaoPlaceURL: serverURL,
                bundleID: bundleID
            )
        )

        XCTAssertEqual(
            link.appURL.absoluteString,
            "kakaomap://search?q=%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98"
        )
        XCTAssertEqual(
            link.webURL.absoluteString,
            "https://m.map.kakao.com/actions/searchView?q=%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98"
        )
    }

    func test_검색어는_예약_글자와_더하기까지_인코딩한다() {
        XCTAssertEqual(PlaceMapLink.encodedQuery("A&B+C 카페/1"), "A%26B%2BC%20%EC%B9%B4%ED%8E%98%2F1")
        XCTAssertEqual(PlaceMapLink.encodedQuery("a-b_c.d~"), "a-b_c.d~")
    }
}
