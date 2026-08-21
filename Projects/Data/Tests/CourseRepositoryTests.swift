import XCTest

@testable import Data

final class CourseRepositoryTests: XCTestCase {
    private let createPath = "/api/v1/date-courses"
    private let placePoolPath = "/api/v1/date-courses/places"

    func test_날짜와_시간을_서버_형식_문자열로_보낸다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(createPath)"] = DateCourseResponseDTO(
            dateCourseId: 42,
            title: "26.08.05 데이트",
            date: "2026-08-05",
            time: "09:05:00",
            status: "DRAFT",
            version: 0
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

    private func makeRepository(network: StubNetworkClient) -> CourseRepository {
        CourseRepository(remote: CourseRemoteDataSource(networkClient: network))
    }
}
