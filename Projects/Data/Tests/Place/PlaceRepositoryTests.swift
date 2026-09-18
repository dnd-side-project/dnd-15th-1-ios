import CoreNetwork
import Domain
import XCTest

@testable import Data

final class PlaceRepositoryTests: XCTestCase {
    private let recentPath = "/api/v1/home/recent-saved-places"

    func test_최근_저장_장소는_홈_주소를_size와_부른다() async throws {
        let network = StubNetworkClient()
        network.responses["GET \(recentPath)"] = [SavedPlaceResponseDTO]()
        let repository = PlaceRepository(remote: PlaceRemoteDataSource(networkClient: network))

        let places = try await repository.recentSavedPlaces(size: 5)

        XCTAssertEqual(network.requestedKeys, ["GET \(recentPath)"])
        XCTAssertTrue(places.isEmpty)
        XCTAssertEqual(
            PlaceEndpoint.recentSavedPlaces(size: 5).queryItems,
            [URLQueryItem(name: "size", value: "5")]
        )
    }

    func test_최근_저장_장소_실패는_PlaceError로_던진다() async {
        let network = StubNetworkClient()
        network.errors["GET \(recentPath)"] = NetworkError.transport(message: "timeout")
        let repository = PlaceRepository(remote: PlaceRemoteDataSource(networkClient: network))

        do {
            _ = try await repository.recentSavedPlaces(size: 5)
            XCTFail("Expected network")
        } catch let error as PlaceError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("Expected PlaceError, got \(error)")
        }
    }
}
