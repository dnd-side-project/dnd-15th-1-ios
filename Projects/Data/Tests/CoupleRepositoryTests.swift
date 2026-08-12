import CoreNetwork
import Domain
import XCTest

@testable import Data

final class CoupleRepositoryTests: XCTestCase {
    private let connectionCodePath = "/api/v1/connection-codes/me"
    private let connectPath = "/api/v1/couples"
    private let currentPath = "/api/v1/couples/me"

    func test_초대코드를_value와_shareURL로_매핑한다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(connectionCodePath)"] = ConnectionCodeResponseDTO(
            code: "ABCDE",
            shareUrl: "https://dulpick.app/invite/ABCDE"
        )

        let repository = makeRepository(network: network)

        let inviteCode = try await repository.inviteCode()

        XCTAssertEqual(inviteCode.value, "ABCDE")
        XCTAssertEqual(inviteCode.shareURL, URL(string: "https://dulpick.app/invite/ABCDE"))
        XCTAssertEqual(network.requestedKeys, ["GET \(connectionCodePath)"])
    }

    func test_공유URL이_파싱되지_않으면_nil로_두고_실패시키지_않는다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(connectionCodePath)"] = ConnectionCodeResponseDTO(
            code: "ABCDE",
            shareUrl: ""
        )

        let repository = makeRepository(network: network)

        let inviteCode = try await repository.inviteCode()

        XCTAssertEqual(inviteCode.value, "ABCDE")
        XCTAssertNil(inviteCode.shareURL)
    }

    func test_연결도_코드를_trim하고_대문자로_정규화해_body에_담는다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(connectPath)"] = CoupleConnectionStatusResponseDTO(
            connected: true,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: CoupleMemberProfileResponseDTO(nickname: "상대방", profileIcon: 4),
            connectedAt: "2026-08-13T10:00:00",
            daysTogether: 1
        )

        let repository = makeRepository(network: network)

        _ = try await repository.connect(inviteCode: "\n abcde \n")

        guard let body = network.requestedBodies["POST \(connectPath)"] as? Data else {
            XCTFail("Expected connect body")
            return
        }
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["connectionCode"] as? String, "ABCDE")
    }

    func test_연결_응답이_connected면_Couple로_매핑한다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(connectPath)"] = CoupleConnectionStatusResponseDTO(
            connected: true,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: CoupleMemberProfileResponseDTO(nickname: "상대방", profileIcon: 4),
            connectedAt: "2026-08-13T10:00:00",
            daysTogether: 1
        )

        let repository = makeRepository(network: network)

        let couple = try await repository.connect(inviteCode: "ABCDE")

        XCTAssertEqual(couple.id, "2026-08-13T10:00:00")
        XCTAssertEqual(couple.partnerNickname, "상대방")
        XCTAssertEqual(couple.partnerIconID, 4)
    }

    func test_연결됐는데_connectedAt이_없으면_id를_빈문자열로_둔다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(connectPath)"] = CoupleConnectionStatusResponseDTO(
            connected: true,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: CoupleMemberProfileResponseDTO(nickname: "상대방", profileIcon: 4),
            connectedAt: nil,
            daysTogether: nil
        )

        let repository = makeRepository(network: network)

        let couple = try await repository.connect(inviteCode: "ABCDE")

        XCTAssertEqual(couple.id, "")
        XCTAssertEqual(couple.partnerNickname, "상대방")
    }

    func test_연결_응답이_미연결이면_unknown을_던진다() async throws {
        let network = StubNetworkClient()
        network.responses["POST \(connectPath)"] = CoupleConnectionStatusResponseDTO(
            connected: false,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: nil,
            connectedAt: nil,
            daysTogether: nil
        )

        let repository = makeRepository(network: network)

        do {
            _ = try await repository.connect(inviteCode: "ABCDE")
            XCTFail("Expected unknown")
        } catch let error as CoupleError {
            XCTAssertEqual(error, .unknown)
        }
    }

    func test_현재_상태가_미연결이면_nil을_준다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(currentPath)"] = CoupleConnectionStatusResponseDTO(
            connected: false,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: nil,
            connectedAt: nil,
            daysTogether: nil
        )

        let repository = makeRepository(network: network)

        let couple = try await repository.current()

        XCTAssertNil(couple)
    }

    func test_현재_상태가_연결이면_Couple을_준다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(currentPath)"] = CoupleConnectionStatusResponseDTO(
            connected: true,
            me: CoupleMemberProfileResponseDTO(nickname: "나", profileIcon: 1),
            partner: CoupleMemberProfileResponseDTO(nickname: "상대방", profileIcon: 2),
            connectedAt: "2026-08-13T10:00:00",
            daysTogether: 10
        )

        let repository = makeRepository(network: network)

        let couple = try await repository.current()

        XCTAssertEqual(couple?.id, "2026-08-13T10:00:00")
        XCTAssertEqual(couple?.partnerNickname, "상대방")
        XCTAssertEqual(couple?.partnerIconID, 2)
    }

    func test_409는_alreadyConnected로_매핑된다() async throws {
        let network = StubNetworkClient()
        network.errors["POST \(connectPath)"] = NetworkError.conflict(message: "connected")

        let repository = makeRepository(network: network)

        do {
            _ = try await repository.connect(inviteCode: "ABCDE")
            XCTFail("Expected alreadyConnected")
        } catch let error as CoupleError {
            XCTAssertEqual(error, .alreadyConnected)
        }
    }

    func test_현재_상태가_404면_커플_없음으로_보고_nil을_준다() async throws {
        let network = StubNetworkClient()
        network.errors["GET \(currentPath)"] = NetworkError.notFound(message: nil)

        let repository = makeRepository(network: network)

        let couple = try await repository.current()

        XCTAssertNil(couple)
    }

    func test_연결에서_404는_여전히_invalidInviteCode를_던진다() async throws {
        let network = StubNetworkClient()
        network.errors["POST \(connectPath)"] = NetworkError.notFound(message: nil)

        let repository = makeRepository(network: network)

        do {
            _ = try await repository.connect(inviteCode: "ABCDE")
            XCTFail("Expected invalidInviteCode")
        } catch let error as CoupleError {
            XCTAssertEqual(error, .invalidInviteCode)
        }
    }

    func test_401은_unauthorized로_매핑된다() async throws {
        let network = StubNetworkClient()
        network.errors["GET \(currentPath)"] = NetworkError.unauthorized

        let repository = makeRepository(network: network)

        do {
            _ = try await repository.current()
            XCTFail("Expected unauthorized")
        } catch let error as CoupleError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    private func makeRepository(network: StubNetworkClient) -> CoupleRepository {
        CoupleRepository(
            coupleRemote: CoupleRemoteDataSource(networkClient: network)
        )
    }
}
