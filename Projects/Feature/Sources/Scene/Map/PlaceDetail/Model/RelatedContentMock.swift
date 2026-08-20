//
//  RelatedContentMock.swift
//  Dulpick
//

import Domain
import Foundation

/// `장소와 관련된 게시물` 그리드의 값. 시안 a06 을 보려면 장소마다 목록이 달라야 해서 id 로 고른다.
/// 서버에 장소별 게시물 조회가 생기면 이 타입을 지우고 클라이언트 호출로 바꾼다
enum RelatedContentMock {
    /// 저장 목록의 `안산반월도서관`. 게시물 없는 화면을 여기서 본다
    static let emptyPlaceID = "5"

    static func contents(for placeID: String) -> [Content] {
        placeID == emptyPlaceID ? [] : defaultContents
    }

    private static let defaultContents: [Content] = (1...8).map { index in
        Content(
            id: "related-\(index)",
            title: titles[(index - 1) % titles.count],
            thumbnailURLs: [URL(string: "https://picsum.photos/id/\(200 + index)/300/400")].compactMap { $0 },
            placeCount: 5
        )
    }

    private static let titles = [
        "새벽까지 함께할 수 있는 데이트 성지 한강뷰 감성카페",
        "한강뷰 데이트 장소",
        "한강뷰 감성",
        "한강뷰",
    ]
}
