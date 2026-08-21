import Domain
import XCTest

@testable import Data

final class CourseDTOMapperTests: XCTestCase {

    func test_코스_응답을_도메인으로_옮긴다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "13:00:00",
            status: "DRAFT",
            version: 0
        )

        let course = try CourseDTOMapper.toDomain(dto)

        XCTAssertEqual(course.id, "42")
        XCTAssertEqual(course.title, "26.08.05 데이트")
        XCTAssertEqual(course.status, .draft)
        XCTAssertEqual(course.version, 0)
        XCTAssertTrue(course.stops.isEmpty)
        XCTAssertTrue(course.legs.isEmpty)
    }

    func test_날짜와_시간을_서울_기준_한_시각으로_합친다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:00:00",
            status: "CONFIRMED",
            version: 3
        )

        let course = try CourseDTOMapper.toDomain(dto)

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: course.scheduledAt
        )

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(parts.hour, 13)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(course.status, .confirmed)
        XCTAssertEqual(course.version, 3)
    }

    func test_초가_생략된_시간을_받아들인다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:00",
            status: "DRAFT",
            version: 0
        )

        let course = try CourseDTOMapper.toDomain(dto)

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: course.scheduledAt
        )

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(parts.hour, 13)
        XCTAssertEqual(parts.minute, 0)
    }

    func test_모르는_상태값은_draft로_둔다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:00:00",
            status: "ARCHIVED",
            version: 0
        )

        XCTAssertEqual(try CourseDTOMapper.toDomain(dto).status, .draft)
    }

    func test_날짜_형식이_아니면_던진다() {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "not-a-date",
            time: "13:00:00",
            status: "DRAFT",
            version: 0
        )

        do {
            _ = try CourseDTOMapper.toDomain(dto)
            XCTFail("Expected unknown")
        } catch let error as CourseError {
            XCTAssertEqual(error, .unknown)
        } catch {
            XCTFail("Expected CourseError.unknown, got \(error)")
        }
    }

    func test_후보_장소_응답을_도메인으로_옮긴다() throws {
        let dto = DateCoursePlaceCandidateResponseDTO(
            placeId: 7,
            name: "장소명",
            address: "경기도 안산시 모모로 145길",
            latitude: 37.5665,
            longitude: 126.9780,
            categoryName: "카페",
            ownershipStatus: "TOGETHER",
            alias: "우리 카페",
            imageUrls: ["https://example.com/a.jpg", ""]
        )

        let candidate = CourseDTOMapper.toDomain(dto)

        XCTAssertEqual(candidate.id, "7")
        XCTAssertEqual(candidate.name, "장소명")
        XCTAssertEqual(candidate.address, "경기도 안산시 모모로 145길")
        XCTAssertEqual(candidate.category, .cafe)
        XCTAssertEqual(candidate.ownership, .together)
        XCTAssertEqual(candidate.alias, "우리 카페")
        XCTAssertEqual(candidate.coordinate.latitude, 37.5665, accuracy: 0.0001)
        XCTAssertEqual(candidate.coordinate.longitude, 126.9780, accuracy: 0.0001)
        XCTAssertEqual(candidate.thumbnailURLs.count, 1)
    }

    func test_카테고리_한글_일곱값을_모두_옮긴다() {
        let pairs: [(String, PlaceCategory)] = [
            ("맛집", .food),
            ("카페", .cafe),
            ("놀거리", .activity),
            ("쇼핑", .shopping),
            ("생활 편의", .convenience),
            ("관광", .tourism),
            ("숙박", .accommodation),
        ]

        for (name, expected) in pairs {
            let dto = DateCoursePlaceCandidateResponseDTO(
                placeId: 1,
                name: "n",
                address: "a",
                latitude: 0,
                longitude: 0,
                categoryName: name,
                ownershipStatus: "MINE",
                alias: nil,
                imageUrls: []
            )

            XCTAssertEqual(CourseDTOMapper.toDomain(dto).category, expected, name)
        }
    }
}
