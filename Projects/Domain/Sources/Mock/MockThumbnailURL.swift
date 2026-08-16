import Foundation

/// `*Client+Mock` 이 쓰는 placeholder 썸네일 URL 생성기.
/// API 연동이 끝나면 mock 과 함께 사라진다
enum MockThumbnailURL {
    static func list(_ count: Int, seed: Int) -> [URL] {
        (0..<count)
            .map { "https://picsum.photos/id/\(seed + $0)/300/300" }
            .compactMap(URL.init(string:))
    }
}
