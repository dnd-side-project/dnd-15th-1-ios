import Domain
import XCTest

@testable import Data

final class CourseRepositoryTests: XCTestCase {
    private let createPath = "/api/v1/date-courses"
    private let placePoolPath = "/api/v1/date-courses/places"
    private let detailPath = "/api/v1/date-courses/42"

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

    func test_저장은_put으로_확정_저장한다() async throws {
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
            title: "26.08.05 데이트",
            scheduledAt: scheduledAt,
            placeIDs: ["10", "11"],
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
                title: "t",
                scheduledAt: Date(),
                placeIDs: ["10", "abc"],
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
