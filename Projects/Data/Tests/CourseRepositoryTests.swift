import Domain
import XCTest

@testable import Data

final class CourseRepositoryTests: XCTestCase {
    private let createPath = "/api/v1/date-courses"
    private let placePoolPath = "/api/v1/date-courses/places"
    private let detailPath = "/api/v1/date-courses/42"
    private let currentPath = "/api/v1/date-courses/current"

    func test_날짜와_시간을_서버_형식_문자열로_보낸다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(createPath)"] = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "09:05:00",
            status: "DRAFT",
            version: 0,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)

        _ = try await repository.createCourse(
            title: "26.08.05 데이트",
            date: DateComponents(year: 2026, month: 8, day: 5),
            time: DateComponents(hour: 9, minute: 5)
        )

        guard let body = network.requestedBodies["POST \(createPath)"] as? Data else {
            XCTFail("Expected create body")
            return
        }
        let sent = try JSONDecoder().decode([String: String].self, from: body)
        XCTAssertEqual(sent["date"], "2026-08-05")
        XCTAssertEqual(sent["time"], "09:05:00")
        XCTAssertEqual(sent["title"], "26.08.05 데이트")
    }

    func test_장소_목록은_places_경로를_부른다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(placePoolPath)"] = DateCoursePlacePoolResponseDTO(places: [])
        let repository = makeRepository(network: network)

        _ = try await repository.coursePlaces()

        XCTAssertEqual(network.requestedKeys, ["GET \(placePoolPath)"])
    }

    func test_코스_조회는_상세_경로를_부른다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(detailPath)"] = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "09:05:00",
            status: "CONFIRMED",
            version: 1,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)

        let course = try await repository.course(id: "42")

        XCTAssertEqual(network.requestedKeys, ["GET \(detailPath)"])
        XCTAssertEqual(course.id, "42")
        XCTAssertEqual(course.version, 1)
    }

    func test_저장은_PUT으로_확정_저장한다() async throws {
        let network = StubNetworkClient()
        network.responses["PUT \(detailPath)"] = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "09:05:00",
            status: "CONFIRMED",
            version: 1,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let scheduledAt = try XCTUnwrap(
            seoul.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 9, minute: 5))
        )

        _ = try await repository.updateCourse(
            id: "42",
            content: DateCourseContent(
                title: "26.08.05 데이트",
                date: scheduledAt,
                time: DateComponents(hour: 9, minute: 5),
                placeIDs: ["10", "11"]
            ),
            version: 0
        )

        XCTAssertEqual(network.requestedKeys, ["PUT \(detailPath)"])
        guard let body = network.requestedBodies["PUT \(detailPath)"] as? Data else {
            XCTFail("Expected save body")
            return
        }
        let sent = try JSONDecoder().decode(SaveBody.self, from: body)
        XCTAssertEqual(sent.title, "26.08.05 데이트")
        XCTAssertEqual(sent.date, "2026-08-05")
        XCTAssertEqual(sent.time, "09:05:00")
        XCTAssertEqual(sent.placeIds, [10, 11])
        XCTAssertEqual(sent.version, 0)
        XCTAssertNil(sent.saveType)
    }

    func test_예정_코스_조회는_current_경로를_부른다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(currentPath)"] = CurrentDateCourseResponseDTO(
            currentDateCourse: DateCourseSummaryResponseDTO(
                dateCourseId: 42,
                title: "26.08.05 데이트",
                date: "2026-08-05",
                time: "09:05:00",
                status: "CONFIRMED",
                version: 1,
                totalPlaceCount: 3
            )
        )
        let repository = makeRepository(network: network)

        let course = try await repository.currentCourse()

        XCTAssertEqual(network.requestedKeys, ["GET \(currentPath)"])
        XCTAssertEqual(course?.id, "42")
        XCTAssertEqual(course?.title, "26.08.05 데이트")
        XCTAssertEqual(course?.status, .confirmed)
        XCTAssertEqual(course?.version, 1)
        XCTAssertEqual(course?.totalPlaceCount, 3)
    }

    func test_예정_코스가_없으면_nil을_돌려준다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(currentPath)"] = CurrentDateCourseResponseDTO(
            currentDateCourse: nil
        )
        let repository = makeRepository(network: network)

        let course = try await repository.currentCourse()

        XCTAssertEqual(network.requestedKeys, ["GET \(currentPath)"])
        XCTAssertNil(course)
    }

    func test_생성에서_시간이_없으면_요청에_time을_안_싣는다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(createPath)"] = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: nil,
            status: "DRAFT",
            version: 0,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)

        _ = try await repository.createCourse(
            title: "26.08.05 데이트",
            date: DateComponents(year: 2026, month: 8, day: 5),
            time: nil
        )

        guard let body = network.requestedBodies["POST \(createPath)"] as? Data else {
            XCTFail("Expected create body")
            return
        }
        let sent = try JSONDecoder().decode(CreateBody.self, from: body)
        XCTAssertNil(sent.time)
    }

    func test_시간이_없으면_요청에_time을_안_싣는다() async throws {
        let path = "/api/v1/date-courses/1001"
        let network = StubNetworkClient()
        network.responses["PUT \(path)"] = DateCourseResponseDTO(
            dateCourseId: 1001,
            title: "성수동 데이트",
            date: "2026-08-16",
            time: nil,
            status: "CONFIRMED",
            version: 3,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)

        _ = try? await repository.updateCourse(
            id: "1001",
            content: DateCourseContent(
                title: "성수동 데이트",
                date: Date(timeIntervalSince1970: 0),
                time: nil,
                placeIDs: ["101"]
            ),
            version: 3
        )

        guard let body = network.requestedBodies["PUT \(path)"] as? Data else {
            XCTFail("Expected save body")
            return
        }
        let sent = try JSONDecoder().decode(SaveBody.self, from: body)
        XCTAssertNil(sent.time)
    }

    func test_시간이_있으면_요청에_time을_싣는다() async throws {
        let path = "/api/v1/date-courses/1001"
        let network = StubNetworkClient()
        network.responses["PUT \(path)"] = DateCourseResponseDTO(
            dateCourseId: 1001,
            title: "성수동 데이트",
            date: "2026-08-16",
            time: "19:30:00",
            status: "CONFIRMED",
            version: 3,
            totalPlaceCount: nil,
            places: nil
        )
        let repository = makeRepository(network: network)

        _ = try? await repository.updateCourse(
            id: "1001",
            content: DateCourseContent(
                title: "성수동 데이트",
                date: Date(timeIntervalSince1970: 0),
                time: DateComponents(hour: 19, minute: 30),
                placeIDs: ["101"]
            ),
            version: 3
        )

        guard let body = network.requestedBodies["PUT \(path)"] as? Data else {
            XCTFail("Expected save body")
            return
        }
        let sent = try JSONDecoder().decode(SaveBody.self, from: body)
        XCTAssertEqual(sent.time, "19:30:00")
    }

    func test_상대_알리기는_경로만_부르고_바디는_없다() async throws {
        let notifyPath = "/api/v1/date-courses/42/notify-partner"
        let network = StubNetworkClient()
        network.responses["POST \(notifyPath)"] = DateCoursePartnerNotifyResponseDTO(
            notified: false,
            partnerMemberId: 124
        )
        let repository = makeRepository(network: network)

        try await repository.notifyPartner(id: "42")

        XCTAssertEqual(network.requestedKeys, ["POST \(notifyPath)"])
        if let body = network.requestedBodies["POST \(notifyPath)"] {
            XCTAssertNil(body)
        } else {
            XCTFail("Expected notify request to be recorded")
        }
    }

    func test_장소ID가_숫자가_아니면_unknown을_던진다() async {
        let network = StubNetworkClient()
        let repository = makeRepository(network: network)

        do {
            _ = try await repository.updateCourse(
                id: "42",
                content: DateCourseContent(
                    title: "t",
                    date: Date(),
                    time: nil,
                    placeIDs: ["10", "abc"]
                ),
                version: 0
            )
            XCTFail("Expected unknown")
        } catch let error as CourseError {
            XCTAssertEqual(error, .unknown)
        } catch {
            XCTFail("Expected CourseError.unknown, got \(error)")
        }

        XCTAssertTrue(network.requestedKeys.isEmpty)
    }

    private struct CreateBody: Decodable {
        let title: String
        let date: String
        let time: String?
    }

    private struct SaveBody: Decodable {
        let title: String
        let date: String
        let time: String?
        let placeIds: [Int64]
        let version: Int
        let saveType: String?
    }

    private func makeRepository(network: StubNetworkClient) -> CourseRepository {
        CourseRepository(remote: CourseRemoteDataSource(networkClient: network))
    }
}
