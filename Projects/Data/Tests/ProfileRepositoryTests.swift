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

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        let profile = try await repository.updateNickname(nickname: "둘픽이", iconID: 2)

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

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        let profile = try await repository.updateNickname(nickname: "새닉", iconID: 3)

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

    func test_PATCH_경로에서_기존_성향이_유지된다() async throws {
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

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        let profile = try await repository.updateNickname(nickname: "새닉", iconID: 3)

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

    func test_성향_수정은_PUT_후_회원조회_순서로_호출한다() async throws {
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

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

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

    func test_401은_unauthorized로_매핑된다() async throws {
        let network = StubNetworkClient()
        network.errors["GET \(memberPath)"] = NetworkError.unauthorized

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        do {
            _ = try await repository.updateNickname(nickname: "둘픽이", iconID: 1)
            XCTFail("Expected unauthorized")
        } catch let error as ProfileError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func test_400은_invalidNickname으로_매핑된다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: true,
            nickname: "이전닉",
            profileIcon: 1,
            datePreferences: nil
        )
        network.errors["PATCH \(profilePath)"] = NetworkError.badRequest(message: "invalid")

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        do {
            _ = try await repository.updateNickname(nickname: "둘픽이", iconID: 1)
            XCTFail("Expected invalidNickname")
        } catch let error as ProfileError {
            XCTAssertEqual(error, .invalidNickname)
        }
    }

    func test_성향_수정후_닉네임이_없으면_unknown을_던진다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(memberPath)"] = MemberResponseDTO(
            memberId: 1,
            onboardingCompleted: false,
            nickname: nil,
            profileIcon: nil,
            datePreferences: nil
        )

        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: network)
        )

        do {
            _ = try await repository.updateDatePreference(
                DatePreference(
                    indoorOutdoor: .indoor,
                    activityLevel: .active,
                    dateTime: .day,
                    dateFocus: .food
                )
            )
            XCTFail("Expected unknown")
        } catch let error as ProfileError {
            XCTAssertEqual(error, .unknown)
        }
    }
}
