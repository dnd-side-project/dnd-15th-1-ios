import Domain
import XCTest

@testable import Data

final class HomeDTOMapperTests: XCTestCase {

    func test_현재_코스를_요약_모델로_옮긴다() throws {
        let dto = HomeSummaryResponseDTO(
            connected: true,
            myNickname: "둘픽이",
            partnerNickname: "오몽이",
            currentDateCourse: HomeDateCourseResponseDTO(
                dateCourseId: 42,
                title: "성수동 데이트",
                date: "2026-08-05",
                time: "13:00:00",
                status: "CONFIRMED",
                version: 1,
                totalPlaceCount: 3
            )
        )

        let summary = HomeDTOMapper.toDomain(dto)

        XCTAssertEqual(summary.currentDateCourse?.id, "42")
        XCTAssertEqual(summary.currentDateCourse?.title, "성수동 데이트")
        XCTAssertEqual(summary.currentDateCourse?.status, .confirmed)
        XCTAssertEqual(summary.currentDateCourse?.version, 1)
        XCTAssertEqual(summary.currentDateCourse?.totalPlaceCount, 3)

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: try XCTUnwrap(summary.currentDateCourse?.scheduledAt)
        )
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(parts.hour, 13)
        XCTAssertEqual(parts.minute, 0)
    }

    func test_time이_null이면_자정으로_읽는다() throws {
        let dto = HomeSummaryResponseDTO(
            connected: true,
            myNickname: "둘픽이",
            partnerNickname: "오몽이",
            currentDateCourse: HomeDateCourseResponseDTO(
                dateCourseId: 1,
                title: "t",
                date: "2026-08-05",
                time: nil,
                status: "CONFIRMED",
                version: 0,
                totalPlaceCount: 0
            )
        )
        let summary = HomeDTOMapper.toDomain(dto)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents(
            [.hour, .minute],
            from: try XCTUnwrap(summary.currentDateCourse?.scheduledAt)
        )
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
    }

    func test_모르는_상태값은_draft로_둔다() throws {
        let dto = HomeSummaryResponseDTO(
            connected: true,
            myNickname: "둘픽이",
            partnerNickname: "오몽이",
            currentDateCourse: HomeDateCourseResponseDTO(
                dateCourseId: 1,
                title: "t",
                date: "2026-08-05",
                time: "13:00:00",
                status: "ARCHIVED",
                version: 0,
                totalPlaceCount: 0
            )
        )

        XCTAssertEqual(HomeDTOMapper.toDomain(dto).currentDateCourse?.status, .draft)
    }

    func test_status와_version이_없어도_지난데이트_목록이_나온다() throws {
        let json = Data("""
        {
          "dateCourses": [
            {
              "dateCourseId": 7,
              "title": "성수역 데이트",
              "date": "2026-08-06",
              "totalPlaceCount": 5
            }
          ],
          "totalCount": 1,
          "hasNext": false
        }
        """.utf8)

        let dto = try JSONDecoder().decode(PastDateCoursesResponseDTO.self, from: json)
        let page = HomeDTOMapper.toPastCoursePage(dto)

        XCTAssertEqual(page.courses.count, 1)
        XCTAssertEqual(page.courses.first?.id, "7")
        XCTAssertEqual(page.courses.first?.title, "성수역 데이트")
        XCTAssertEqual(page.courses.first?.placeCount, 5)
        XCTAssertEqual(page.courses.first?.date, "26.08.06")
        XCTAssertEqual(page.totalCount, 1)
        XCTAssertFalse(page.hasNext)
    }

    func test_날짜가_깨진_현재코스는_나머지를_살린다() {
        let dto = HomeSummaryResponseDTO(
            connected: true,
            myNickname: "둘픽이",
            partnerNickname: "오몽이",
            currentDateCourse: HomeDateCourseResponseDTO(
                dateCourseId: 1,
                title: "t",
                date: "not-a-date",
                time: "13:00:00",
                status: "CONFIRMED",
                version: 1,
                totalPlaceCount: 3
            )
        )

        let summary = HomeDTOMapper.toDomain(dto)

        XCTAssertTrue(summary.connected)
        XCTAssertEqual(summary.myNickname, "둘픽이")
        XCTAssertEqual(summary.partnerNickname, "오몽이")
        XCTAssertNil(summary.currentDateCourse)
    }
}
