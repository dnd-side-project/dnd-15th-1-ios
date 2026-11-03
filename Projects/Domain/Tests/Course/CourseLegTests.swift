import Domain
import SharedUtils
import XCTest

final class CourseLegTests: XCTestCase {

    private let walkPoint = Coordinate(latitude: 37.5446, longitude: 127.0557)
    private let transitPoint = Coordinate(latitude: 37.5172, longitude: 127.0473)

    func test_대중교통이_없으면_도보_값이_보인다() {
        let leg = CourseLeg(walkingMinutes: 20, distanceMeters: 1500, walkingPath: [walkPoint])

        XCTAssertEqual(leg.travelMode, .walking)
        XCTAssertEqual(leg.travelMinutes, 20)
        XCTAssertEqual(leg.travelDistanceMeters, 1500)
        XCTAssertEqual(leg.travelPath, [walkPoint])
    }

    func test_대중교통이_있으면_대중교통_값이_보인다() {
        let leg = CourseLeg(
            walkingMinutes: 80,
            distanceMeters: 5300,
            walkingPath: [walkPoint],
            transit: CourseTransit(minutes: 45, distanceMeters: 5200, path: [transitPoint])
        )

        XCTAssertEqual(leg.travelMode, .transit)
        XCTAssertEqual(leg.travelMinutes, 45)
        XCTAssertEqual(leg.travelDistanceMeters, 5200)
        XCTAssertEqual(leg.travelPath, [transitPoint])
    }

    func test_대중교통_경로가_비어도_도보_경로로_바꾸지_않는다() {
        let leg = CourseLeg(
            walkingMinutes: 80,
            distanceMeters: 5300,
            walkingPath: [walkPoint],
            transit: CourseTransit(minutes: 45, distanceMeters: 5200, path: [])
        )

        XCTAssertEqual(leg.travelMode, .transit)
        XCTAssertTrue(leg.travelPath.isEmpty)
    }
}
