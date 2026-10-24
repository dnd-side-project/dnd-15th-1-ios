import Domain
import Foundation
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

    func test_날짜와_시간을_나눠_읽는다() throws {
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
            [.year, .month, .day],
            from: course.scheduledDate
        )

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(course.scheduledTime?.hour, 13)
        XCTAssertEqual(course.scheduledTime?.minute, 0)
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
            [.year, .month, .day],
            from: course.scheduledDate
        )

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(course.scheduledTime?.hour, 13)
        XCTAssertEqual(course.scheduledTime?.minute, 0)
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

    func test_시간_형식이_아니면_던진다() {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "어쩌구",
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

    func test_시간의_분_자리를_못_읽으면_던진다() {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "13:ab:45",
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

    func test_시간의_시가_범위_밖이면_던진다() {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: "25:00:00",
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

    func test_시간이_없으면_예정_시간도_없다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1001,
            title: "성수동 데이트",
            date: "2026-08-16",
            time: nil,
            status: "CONFIRMED",
            version: 3,
            totalPlaceCount: 0,
            places: []
        )

        let course = try CourseDTOMapper.toDomain(dto)

        XCTAssertNil(course.scheduledTime)
    }

    func test_시간이_있으면_시와_분을_읽는다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1001,
            title: "성수동 데이트",
            date: "2026-08-16",
            time: "19:30:00",
            status: "CONFIRMED",
            version: 3,
            totalPlaceCount: 0,
            places: []
        )

        let course = try CourseDTOMapper.toDomain(dto)

        XCTAssertEqual(course.scheduledTime?.hour, 19)
        XCTAssertEqual(course.scheduledTime?.minute, 30)
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

    func test_시간이_없으면_자정으로_읽는다() throws {
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
            roadAddress: "",
            latitude: 37.5665,
            longitude: 126.9780,
            categoryName: "카페",
            ownershipStatus: "TOGETHER",
            alias: "우리 카페",
            thumbnailUrl: "https://example.com/t.jpg",
            imageUrls: ["https://example.com/a.jpg", ""]
        )

        let candidate = CourseDTOMapper.toDomain(dto)

        XCTAssertEqual(candidate.id, "7")
        XCTAssertEqual(candidate.place.placeID, "7")
        XCTAssertEqual(candidate.place.name, "장소명")
        XCTAssertEqual(candidate.place.address, "경기도 안산시 모모로 145길")
        // 서버가 도로명 없음을 "" 로 주는 응답이 있다
        XCTAssertNil(candidate.place.roadAddress)
        XCTAssertEqual(candidate.place.category, .cafe)
        XCTAssertEqual(candidate.ownership, .together)
        XCTAssertEqual(candidate.alias, "우리 카페")
        XCTAssertEqual(candidate.place.coordinate.latitude, 37.5665, accuracy: 0.0001)
        XCTAssertEqual(candidate.place.coordinate.longitude, 126.9780, accuracy: 0.0001)
        XCTAssertEqual(candidate.place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
        // 이 응답에 없는 값은 지어내지 않는다
        XCTAssertNil(candidate.place.kakaoPlaceID)
        XCTAssertNil(candidate.place.bookmarkCount)
        XCTAssertNil(candidate.savedAt)
    }
}

final class CourseDTOMapperPhotoTests: XCTestCase {

    func test_후보_장소의_모르는_저장_관계는_mine이다() {
        let dto = DateCoursePlaceCandidateResponseDTO(
            placeId: 7,
            name: "장소명",
            address: "주소",
            roadAddress: nil,
            latitude: 37.5,
            longitude: 127.0,
            categoryName: "카페",
            ownershipStatus: "???",
            alias: nil,
            thumbnailUrl: nil,
            imageUrls: []
        )

        XCTAssertEqual(CourseDTOMapper.toDomain(dto).ownership, .mine)
    }

    func test_코스_장소에_지번_주소가_없으면_읽기에_실패한다() {
        let json = Data("""
        {
          "order": 1,
          "placeId": 7,
          "name": "장소7",
          "roadAddress": "도로명",
          "latitude": 37.5,
          "longitude": 127.0
        }
        """.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(DateCoursePlaceResponseDTO.self, from: json))
    }

    func test_코스_장소는_장소_번호와_카테고리와_사진을_옮기고_빈_도로명은_없음으로_읽고_저장_수는_모른다() throws {
        let dto = DateCourseResponseDTO(
            dateCourseId: 1,
            title: "t",
            date: "2026-08-05",
            time: nil,
            status: "CONFIRMED",
            version: 1,
            totalPlaceCount: 1,
            places: [
                DateCoursePlaceResponseDTO(
                    order: 1,
                    placeId: 7,
                    name: "장소7",
                    address: "주소",
                    roadAddress: "",
                    latitude: 37.5,
                    longitude: 127.0,
                    category: nil,
                    categoryName: "카페",
                    thumbnailUrl: "https://example.com/t.jpg",
                    imageUrls: ["https://example.com/a.jpg"],
                    walkToNext: nil
                ),
            ]
        )

        let place = try XCTUnwrap(try CourseDTOMapper.toDomain(dto).stops.first?.place)

        XCTAssertEqual(place.placeID, "7")
        XCTAssertEqual(place.category, .cafe)
        XCTAssertEqual(place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
        XCTAssertNil(place.roadAddress)
        XCTAssertNil(place.bookmarkCount)
    }
}

final class CourseDTOMapperPastTests: XCTestCase {

    func test_상태와_버전이_없어도_지난_데이트를_읽고_상태는_nil이다() throws {
        let json = Data("""
        {
          "dateCourses": [
            { "dateCourseId": 7, "title": "성수역 데이트", "date": "2026-08-06", "totalPlaceCount": 5 }
          ],
          "totalCount": 1,
          "hasNext": false
        }
        """.utf8)
        let dto = try JSONDecoder().decode(PastDateCoursesResponseDTO.self, from: json)

        let page = try CourseDTOMapper.toPage(dto)

        XCTAssertEqual(page.courses.map(\.id), ["7"])
        XCTAssertEqual(page.courses.first?.title, "성수역 데이트")
        XCTAssertEqual(page.courses.first?.totalPlaceCount, 5)
        XCTAssertNil(page.courses.first?.status)
        // 2026-08-06 00:00 Asia/Seoul
        XCTAssertEqual(page.courses.first?.scheduledAt, Date(timeIntervalSince1970: 1_785_942_000))
        XCTAssertEqual(page.totalCount, 1)
        XCTAssertFalse(page.hasNext)
    }

    func test_지난_데이트_날짜를_못_읽으면_목록_읽기가_실패한다() {
        let dto = PastDateCoursesResponseDTO(
            dateCourses: [
                DateCourseSummaryResponseDTO(
                    dateCourseId: 7,
                    title: "t",
                    date: "not-a-date",
                    time: nil,
                    status: nil,
                    version: nil,
                    totalPlaceCount: 1
                ),
            ],
            totalCount: 1,
            hasNext: false
        )

        XCTAssertThrowsError(try CourseDTOMapper.toPage(dto)) { error in
            XCTAssertEqual(error as? CourseError, .unknown)
        }
    }
}
