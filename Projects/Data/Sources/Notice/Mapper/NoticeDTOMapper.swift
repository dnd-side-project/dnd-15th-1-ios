import Domain
import Foundation

enum NoticeDTOMapper {
    static func toDomain(_ dto: NoticePageResponseDTO) -> NoticePage {
        NoticePage(
            items: dto.notices.map(toNotice),
            hasNext: dto.hasNext
        )
    }

    private static func toNotice(_ dto: NoticeResponseDTO) -> Notice {
        Notice(
            id: String(dto.noticeId),
            title: dto.title,
            content: dto.content,
            createdAt: dto.createdAt
        )
    }
}
