import Domain
import Foundation
import XCTest

@testable import Data

final class NoticeDTOMapperTests: XCTestCase {
    func test_숫자_식별자를_문자열로_바꾼다() {
        let page = NoticeDTOMapper.toDomain(pageDTO(notices: [noticeDTO(noticeId: 42)]))

        XCTAssertEqual(page.items.first?.id, "42")
    }

    func test_빈_목록은_빈_배열이_된다() {
        let page = NoticeDTOMapper.toDomain(pageDTO(notices: []))

        XCTAssertTrue(page.items.isEmpty)
    }

    func test_다음_페이지_여부를_그대로_옮긴다() {
        XCTAssertTrue(NoticeDTOMapper.toDomain(pageDTO(hasNext: true)).hasNext)
        XCTAssertFalse(NoticeDTOMapper.toDomain(pageDTO(hasNext: false)).hasNext)
    }

    func test_제목과_본문과_작성_시각을_옮긴다() throws {
        let created = Date(timeIntervalSince1970: 1_788_742_800)
        let page = NoticeDTOMapper.toDomain(
            pageDTO(notices: [
                noticeDTO(title: "점검 안내", content: "새벽에 점검합니다.", createdAt: created),
            ])
        )

        let notice = try XCTUnwrap(page.items.first)
        XCTAssertEqual(notice.title, "점검 안내")
        XCTAssertEqual(notice.content, "새벽에 점검합니다.")
        XCTAssertEqual(notice.createdAt, created)
    }

    func test_여러_건의_차례를_그대로_지킨다() {
        let page = NoticeDTOMapper.toDomain(
            pageDTO(notices: [
                noticeDTO(noticeId: 1),
                noticeDTO(noticeId: 2),
                noticeDTO(noticeId: 3),
            ])
        )

        XCTAssertEqual(page.items.map(\.id), ["1", "2", "3"])
    }

    private func noticeDTO(
        noticeId: Int64 = 1,
        title: String = "제목",
        content: String = "본문",
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> NoticeResponseDTO {
        NoticeResponseDTO(
            noticeId: noticeId,
            title: title,
            content: content,
            createdAt: createdAt
        )
    }

    private func pageDTO(
        notices: [NoticeResponseDTO] = [],
        hasNext: Bool = false
    ) -> NoticePageResponseDTO {
        NoticePageResponseDTO(notices: notices, hasNext: hasNext)
    }
}
