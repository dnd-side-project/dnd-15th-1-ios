import Foundation

/// 게시물 목록 응답. 한 페이지와 함께 탐색 필터칩으로 쓰는 인기 태그가 온다.
/// 검색·장소별 게시물 응답에는 인기 태그가 없어 그쪽은 ContentPage 만 받는다
public struct ContentFeed: Equatable, Sendable {
    public let page: ContentPage
    /// 첫 페이지 응답에 담겨 온다. 없으면 빈 목록이다
    public let popularTags: [String]

    public init(page: ContentPage, popularTags: [String]) {
        self.page = page
        self.popularTags = popularTags
    }
}
