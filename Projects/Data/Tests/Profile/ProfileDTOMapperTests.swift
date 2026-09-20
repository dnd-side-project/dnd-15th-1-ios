import Domain
import XCTest

@testable import Data

final class ProfileDTOMapperTests: XCTestCase {

    func test_성향을_서버_문자열로_보낸다() {
        let request = ProfileDTOMapper.toRequest(
            DatePreference(
                indoorOutdoor: .outdoor,
                activityLevel: .`static`,
                dateTime: .night,
                dateFocus: .sightseeing
            )
        )

        XCTAssertEqual(request.indoorOutdoor, "OUTDOOR")
        XCTAssertEqual(request.activityLevel, "STATIC")
        XCTAssertEqual(request.dateTime, "NIGHT")
        XCTAssertEqual(request.dateFocus, "SIGHTSEEING")
    }

    func test_서버_문자열_네_축을_성향으로_읽는다() {
        let preference = ProfileDTOMapper.toDatePreference(
            MemberDatePreferencesResponseDTO(
                indoorOutdoor: "INDOOR",
                activityLevel: "ACTIVE",
                dateTime: "DAY",
                dateFocus: "FOOD"
            )
        )

        XCTAssertEqual(
            preference,
            DatePreference(indoorOutdoor: .indoor, activityLevel: .active, dateTime: .day, dateFocus: .food)
        )
    }

    func test_한_축이라도_모르는_값이면_성향이_없다() {
        let preference = ProfileDTOMapper.toDatePreference(
            MemberDatePreferencesResponseDTO(
                indoorOutdoor: "INDOOR",
                activityLevel: "ACTIVE",
                dateTime: "EVENING",
                dateFocus: "FOOD"
            )
        )

        XCTAssertNil(preference)
    }
}
