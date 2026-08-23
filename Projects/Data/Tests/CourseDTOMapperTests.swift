import Domain
import XCTest

@testable import Data

final class CourseDTOMapperCourseTests: XCTestCase {

    func test_코스_응답을_도메인으로_옮긴다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "13:00:00",
            status: "DRAFT",
            version: 0,
            totalPlaceCount: nil,
            places: nil
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
            version: 3,
            totalPlaceCount: nil,
            places: nil
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
            version: 0,
            totalPlaceCount: nil,
            places: nil
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
            version: 0,
            totalPlaceCount: nil,
            places: nil
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
            version: 0,
            totalPlaceCount: nil,
            places: nil
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

    func test_time이_null이면_자정으로_읽는다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: nil,
            status: "DRAFT",
            version: 0,
            totalPlaceCount: 0,
            places: []
        )
        let course = try CourseDTOMapper.toDomain(dto)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents([.hour, .minute], from: course.scheduledAt)
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
    }
}

final class CourseDTOMapperSummaryTests: XCTestCase {

    func test_요약_응답을_도메인으로_옮긴다() throws {
        let dto = DateCourseSummaryResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "13:00:00",
            status: "CONFIRMED",
            version: 1,
            totalPlaceCount: 3
        )

        let summary = try CourseDTOMapper.toDomain(dto)

        XCTAssertEqual(summary.id, "42")
        XCTAssertEqual(summary.title, "26.08.05 데이트")
        XCTAssertEqual(summary.status, .confirmed)
        XCTAssertEqual(summary.version, 1)
        XCTAssertEqual(summary.totalPlaceCount, 3)

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: summary.scheduledAt
        )
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(parts.hour, 13)
        XCTAssertEqual(parts.minute, 0)
    }

    func test_time이_null이면_자정으로_읽는다() throws {
        let dto = DateCourseSummaryResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: nil,
            status: "CONFIRMED",
            version: 0,
            totalPlaceCount: 0
        )
        let summary = try CourseDTOMapper.toDomain(dto)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let parts = seoul.dateComponents([.hour, .minute], from: summary.scheduledAt)
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
    }

    func test_모르는_상태값은_draft로_둔다() throws {
        let dto = DateCourseSummaryResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:00:00",
            status: "ARCHIVED",
            version: 0,
            totalPlaceCount: 0
        )

        XCTAssertEqual(try CourseDTOMapper.toDomain(dto).status, .draft)
    }
}

final class CourseDTOMapperLegTests: XCTestCase {

    func test_구간을_장소_사이_개수만큼_만든다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: nil,
            status: "CONFIRMED",
            version: 2,
            totalPlaceCount: 3,
            places: [
                place(order: 1, id: 10, walk: (1500, 1200)),
                place(order: 2, id: 11, walk: (5300, 4800)),
                place(order: 3, id: 12, walk: nil),
            ]
        )
        let course = try CourseDTOMapper.toDomain(dto)
        XCTAssertEqual(course.stops.count, 3)
        XCTAssertEqual(course.legs.count, 2)
        XCTAssertEqual(course.legs[0]?.walkingMinutes, 20)
        XCTAssertEqual(course.legs[0]?.distanceMeters, 1500)
        XCTAssertEqual(course.legs[1]?.walkingMinutes, 80)
    }

    func test_첫_구간이_없어도_자리는_유지한다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: nil,
            status: "CONFIRMED",
            version: 2,
            totalPlaceCount: 4,
            places: [
                place(order: 1, id: 10, walk: nil),
                place(order: 2, id: 11, walk: (1500, 1200)),
                place(order: 3, id: 12, walk: (5300, 4800)),
                place(order: 4, id: 13, walk: nil),
            ]
        )
        let course = try CourseDTOMapper.toDomain(dto)
        XCTAssertEqual(course.stops.count, 4)
        XCTAssertEqual(course.legs.count, 3)
        XCTAssertNil(course.legs[0])
        XCTAssertEqual(course.legs[1]?.walkingMinutes, 20)
        XCTAssertEqual(course.legs[1]?.distanceMeters, 1500)
        XCTAssertEqual(course.legs[2]?.walkingMinutes, 80)
        XCTAssertEqual(course.legs[2]?.distanceMeters, 5300)
        XCTAssertEqual(course.totalWalkingMinutes, 100)
        XCTAssertEqual(course.totalDistanceMeters, 6800)
    }

    func test_도보_초는_분으로_반올림한다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:00:00",
            status: "CONFIRMED",
            version: 1,
            totalPlaceCount: 2,
            places: [
                place(order: 1, id: 10, walk: (100, 90)),
                place(order: 2, id: 11, walk: nil),
            ]
        )
        let course = try CourseDTOMapper.toDomain(dto)
        XCTAssertEqual(course.legs[0]?.walkingMinutes, 2)
    }

    private func place(
        order: Int,
        id: Int64,
        walk: (Int, Int)?
    ) -> DateCoursePlaceResponseDTO {
        DateCoursePlaceResponseDTO(
            order: order,
            placeId: id,
            name: "장소\(id)",
            address: "주소",
            roadAddress: "도로명",
            latitude: 37.5,
            longitude: 127.0,
            category: nil,
            categoryName: "카페",
            thumbnailUrl: nil,
            imageUrls: nil,
            walkToNext: walk.map {
                WalkToNextResponseDTO(distanceMeters: $0.0, durationSeconds: $0.1)
            }
        )
    }
}

final class CourseDTOMapperCandidateTests: XCTestCase {

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
