import Foundation

/// 장소 상세 지도 시트에서 고르는 지도 앱. 시트에 보이는 차례다
public enum PlaceMapApp: Equatable, Sendable, CaseIterable {
    case naver
    case kakao
}

/// 지도 앱 하나를 여는 주소 한 쌍. 앱 주소를 먼저 열고, 실패하면 웹 주소를 연다
struct PlaceMapLink: Equatable, Sendable {
    let appURL: URL
    let webURL: URL
}

extension PlaceMapLink {
    /// - Parameters:
    ///   - app: 열 지도 앱
    ///   - name: 검색어로 쓸 실제 장소 이름. 별칭을 넘기지 않는다
    ///   - kakaoPlaceID: 카카오 장소 번호. 있으면 카카오는 장소 화면을, 없으면 이름 검색을 연다
    ///   - kakaoPlaceURL: 서버가 준 카카오 웹 주소. 카카오 번호가 있을 때만 쓴다
    ///   - bundleID: 네이버가 요구하는 `appname`. 실행 중인 앱의 번들 id 다
    /// - Returns: 주소를 만들 수 없으면 nil
    static func make(
        app: PlaceMapApp,
        name: String,
        kakaoPlaceID: String?,
        kakaoPlaceURL: URL?,
        bundleID: String
    ) -> PlaceMapLink? {
        let query = encodedQuery(name)
        let appString: String
        let webURL: URL?
        switch app {
        case .naver:
            appString = "nmap://search?query=\(query)&appname=\(encodedQuery(bundleID))"
            webURL = URL(string: "https://m.map.naver.com/search?query=\(query)")
        case .kakao:
            if let kakaoPlaceID {
                appString = "kakaomap://place?id=\(kakaoPlaceID)"
                webURL = kakaoPlaceURL ?? URL(string: "https://place.map.kakao.com/\(kakaoPlaceID)")
            } else {
                appString = "kakaomap://search?q=\(query)"
                webURL = URL(string: "https://m.map.kakao.com/actions/searchView?q=\(query)")
            }
        }
        guard let appURL = URL(string: appString), let webURL else { return nil }
        return PlaceMapLink(appURL: appURL, webURL: webURL)
    }

    /// 검색어를 RFC 3986 의 예약 안 된 글자만 남기고 퍼센트 인코딩한다.
    /// `URLComponents.queryItems` 는 `+` 를 그대로 둬 받는 쪽이 공백으로 읽는다. 그래서 직접 인코딩한다
    static func encodedQuery(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? ""
    }

    private static let unreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
