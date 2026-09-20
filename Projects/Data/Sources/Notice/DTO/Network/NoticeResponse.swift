import Foundation

/// 화면이 쓰는 필드만 선언한다. 나머지 키는 디코딩에서 무시된다
struct NoticePageResponseDTO: Decodable, Sendable {
    let notices: [NoticeResponseDTO]
    let hasNext: Bool
}

struct NoticeResponseDTO: Decodable, Sendable {
    let noticeId: Int64
    let title: String
    let content: String
    let createdAt: Date
}
