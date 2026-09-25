import Foundation

/// `*Client+Mock` 이 쓰는 placeholder 썸네일 URL 생성기.
/// 개념이 없는 보조 코드라 Domain 개념 폴더가 아니라 여기 둔다
public enum MockThumbnailURL {
    public static func list(_ count: Int, seed: Int) -> [URL] {
        (0..<count)
            .map { "https://picsum.photos/id/\(seed + $0)/300/300" }
            .compactMap(URL.init(string:))
    }
}
