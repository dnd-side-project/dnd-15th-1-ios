import CoreNetwork
import Domain
import XCTest

@testable import Data

final class NotificationRepositoryTests: XCTestCase {
    private let settingsPath = "/api/v1/members/me/notification-settings"

    func test_알림_설정_조회는_회원_알림_설정_주소를_부른다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(settingsPath)"] = NotificationSettingsResponseDTO(
            contentSavedEnabled: true,
            dateScheduleEnabled: false,
            marketingEnabled: false,
            marketingConsentVersion: nil,
            availableMarketingConsentVersion: "v1"
        )
        let repository = makeRepository(network: network)

        let settings = try await repository.notificationSettings()

        XCTAssertEqual(network.requestedKeys, ["GET \(settingsPath)"])
        XCTAssertTrue(settings.contentSavedEnabled)
        XCTAssertEqual(settings.availableMarketingConsentVersion, "v1")
    }

    func test_알림_설정_변경은_PUT으로_세_값과_동의_버전을_보낸다() async throws {
        let network = StubNetworkClient()
        network.responses["PUT \(settingsPath)"] = NotificationSettingsResponseDTO(
            contentSavedEnabled: true,
            dateScheduleEnabled: true,
            marketingEnabled: true,
            marketingConsentVersion: "v1",
            availableMarketingConsentVersion: "v1"
        )
        let repository = makeRepository(network: network)

        _ = try await repository.updateNotificationSettings(
            NotificationSettings(
                contentSavedEnabled: true,
                dateScheduleEnabled: true,
                marketingEnabled: true,
                marketingConsentVersion: "v1"
            )
        )

        guard let body = network.requestedBodies["PUT \(settingsPath)"] as? Data else {
            XCTFail("Expected body")
            return
        }
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["marketingEnabled"] as? Bool, true)
        XCTAssertEqual(json["marketingConsentVersion"] as? String, "v1")
    }

    func test_알림_설정_실패는_NotificationError로_던진다() async {
        let network = StubNetworkClient()
        network.errors["GET \(settingsPath)"] = NetworkError.transport(message: "timeout")
        let repository = makeRepository(network: network)

        do {
            _ = try await repository.notificationSettings()
            XCTFail("Expected network")
        } catch let error as NotificationError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("Expected NotificationError, got \(error)")
        }
    }

    private func makeRepository(network: StubNetworkClient) -> NotificationRepository {
        NotificationRepository(
            notificationRemote: NotificationRemoteDataSource(networkClient: network),
            notificationLocal: NotificationLocalDataSource(storage: StubKeychainStorage()),
            appVersion: nil
        )
    }
}
