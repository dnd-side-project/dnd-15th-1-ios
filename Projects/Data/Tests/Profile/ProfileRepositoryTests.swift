import CoreNetwork
import Domain
import XCTest

@testable import Data

final class ProfileRepositoryTests: XCTestCase {
    private let memberPath = "/api/v1/members/me"
    private let profilePath = "/api/v1/members/me/profile"
    private let datePreferencesPath = "/api/v1/members/me/date-preferences"

    func test_온보딩_미완료면_POST로_초기화하고_성향키를_보내지_않는다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: false,
            nickname: nil,
            profileIcon: nil,
            datePreferences: nil
        )
        network.responses["POST \(profilePath)"] = InitializedMemberProfileResponseDTO(
            nickname: "둘픽이",
            profileIcon: 2,
            datePreferences: nil,
            connectionCode: "ABCDE",
            shareUrl: "https://dulpick.app/invite/ABCDE"
        )

        let repository = makeRepository(network: network)

        let profile = try await repository.setUpProfile(nickname: "둘픽이", iconID: 2)

        XCTAssertEqual(profile.nickname, "둘픽이")
        XCTAssertEqual(profile.iconID, 2)
        XCTAssertNil(profile.datePreference)
        XCTAssertEqual(
            network.requestedKeys,
            ["GET \(memberPath)", "POST \(profilePath)"]
        )

        guard let body = network.requestedBodies["POST \(profilePath)"] as? Data else {
            XCTFail("Expected initialize profile body")
            return
        }
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["nickname"] as? String, "둘픽이")
        XCTAssertEqual(json?["profileIcon"] as? Int, 2)
        XCTAssertNil(json?["datePreferences"])
        XCTAssertEqual(json?.count, 2)
    }

    func test_온보딩_완료면_PATCH로_수정하고_성향키를_보내지_않는다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: true,
            nickname: "이전닉",
            profileIcon: 1,
            datePreferences: nil
        )
        network.responses["PATCH \(profilePath)"] = UpdatedMemberProfileResponseDTO(
            nickname: "새닉",
            profileIcon: 3
        )

        let repository = makeRepository(network: network)

        let profile = try await repository.setUpProfile(nickname: "새닉", iconID: 3)

        XCTAssertEqual(profile.nickname, "새닉")
        XCTAssertEqual(profile.iconID, 3)
        XCTAssertEqual(
            network.requestedKeys,
            ["GET \(memberPath)", "PATCH \(profilePath)"]
        )

        guard let body = network.requestedBodies["PATCH \(profilePath)"] as? Data else {
            XCTFail("Expected update profile body")
            return
        }
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["nickname"] as? String, "새닉")
        XCTAssertEqual(json?["profileIcon"] as? Int, 3)
        XCTAssertFalse(json?.keys.contains("datePreferences") == true)
    }

    func test_온보딩_완료면_프로필을_수정해도_기존_성향이_유지된다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: true,
            nickname: "이전닉",
            profileIcon: 1,
            datePreferences: MemberDatePreferencesResponseDTO(
                indoorOutdoor: "OUTDOOR",
                activityLevel: "STATIC",
                dateTime: "NIGHT",
                dateFocus: "SIGHTSEEING"
            )
        )
        network.responses["PATCH \(profilePath)"] = UpdatedMemberProfileResponseDTO(
            nickname: "새닉",
            profileIcon: 3
        )

        let repository = makeRepository(network: network)

        let profile = try await repository.setUpProfile(nickname: "새닉", iconID: 3)

        XCTAssertEqual(
            profile.datePreference,
            DatePreference(
                indoorOutdoor: .outdoor,
                activityLevel: .static,
                dateTime: .night,
                dateFocus: .sightseeing
            )
        )
    }

    func test_성향_수정은_새_성향을_보내고_다시_조회한_프로필을_돌려준다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: true,
            nickname: "둘픽이",
            profileIcon: 4,
            datePreferences: MemberDatePreferencesResponseDTO(
                indoorOutdoor: "INDOOR",
                activityLevel: "ACTIVE",
                dateTime: "DAY",
                dateFocus: "FOOD"
            )
        )

        let repository = makeRepository(network: network)

        let preference = DatePreference(
            indoorOutdoor: .indoor,
            activityLevel: .active,
            dateTime: .day,
            dateFocus: .food
        )
        let profile = try await repository.updateDatePreference(preference)

        XCTAssertEqual(profile.nickname, "둘픽이")
        XCTAssertEqual(profile.iconID, 4)
        XCTAssertEqual(profile.datePreference, preference)
        XCTAssertEqual(
            network.requestedKeys,
            ["PUT \(datePreferencesPath)", "GET \(memberPath)"]
        )

        guard let body = network.requestedBodies["PUT \(datePreferencesPath)"] as? Data else {
            XCTFail("Expected date preferences body")
            return
        }
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["indoorOutdoor"] as? String, "INDOOR")
        XCTAssertEqual(json?["activityLevel"] as? String, "ACTIVE")
        XCTAssertEqual(json?["dateTime"] as? String, "DAY")
        XCTAssertEqual(json?["dateFocus"] as? String, "FOOD")
    }

    func test_프로필_설정_실패는_ProfileError로_던진다() async {
        let network = StubNetworkClient()
        network.errors["GET \(memberPath)"] = NetworkError.unauthorized

        let repository = makeRepository(network: network)

        await assertThrows(ProfileError.unauthorized) {
            try await repository.setUpProfile(nickname: "둘픽이", iconID: 1)
        }
    }

    func test_성향_수정후_닉네임이_없으면_unknown을_던진다() async {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: false,
            nickname: nil,
            profileIcon: nil,
            datePreferences: nil
        )

        let repository = makeRepository(network: network)

        await assertThrows(ProfileError.unknown) {
            try await repository.updateDatePreference(
                DatePreference(
                    indoorOutdoor: .indoor,
                    activityLevel: .active,
                    dateTime: .day,
                    dateFocus: .food
                )
            )
        }
    }

    private func makeRepository(network: StubNetworkClient) -> ProfileRepository {
        ProfileRepository(profileRemote: ProfileRemoteDataSource(networkClient: network))
    }
}
