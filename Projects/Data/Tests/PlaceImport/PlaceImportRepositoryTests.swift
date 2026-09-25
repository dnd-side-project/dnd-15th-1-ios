import CoreNetwork
import Domain
import XCTest

@testable import Data

final class PlaceImportRepositoryTests: XCTestCase {
    private let confirmPath = "/api/v1/place-imports/9/confirm"

    func test_확정은_후보_번호를_숫자로_바꿔_보낸다() async throws {
        let network = StubNetworkClient()
        let repository = PlaceImportRepository(remote: PlaceImportRemoteDataSource(networkClient: network))

        try await repository.confirm(importID: "9", candidateIDs: ["1", "2"])

        XCTAssertEqual(network.requestedKeys, ["POST \(confirmPath)"])
        guard let body = network.requestedBodies["POST \(confirmPath)"] as? Data else {
            XCTFail("Expected confirm body")
            return
        }
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let selections = try XCTUnwrap(json["selections"] as? [[String: Any]])
        XCTAssertEqual(selections.compactMap { $0["candidateId"] as? Int }, [1, 2])
    }

    func test_후보_번호가_숫자가_아니면_보내지_않고_unknown을_던진다() async {
        let network = StubNetworkClient()
        let repository = PlaceImportRepository(remote: PlaceImportRemoteDataSource(networkClient: network))

        do {
            try await repository.confirm(importID: "9", candidateIDs: ["abc"])
            XCTFail("Expected unknown")
        } catch let error as PlaceImportError {
            XCTAssertEqual(error, .unknown)
        } catch {
            XCTFail("Expected PlaceImportError, got \(error)")
        }
        XCTAssertTrue(network.requestedKeys.isEmpty)
    }
}
