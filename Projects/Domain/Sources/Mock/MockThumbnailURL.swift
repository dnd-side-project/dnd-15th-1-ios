//
//  MockThumbnailURL.swift
//  Dulpick
//
//  임시 mock 데이터 전용 헬퍼. 실제 응답 매핑에는 쓰지 않는다
//

import Foundation

/// `*Client+Mock` 이 쓰는 자리표시자 썸네일 URL 생성기.
/// API 연동이 끝나면 mock 과 함께 사라진다
enum MockThumbnailURL {
    static func list(_ count: Int, seed: Int) -> [URL] {
        (0..<count)
            .map { "https://picsum.photos/id/\(seed + $0)/300/300" }
            .compactMap(URL.init(string:))
    }
}
