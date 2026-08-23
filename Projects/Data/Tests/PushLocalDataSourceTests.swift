import CoreStorage
import XCTest

@testable import Data

final class PushLocalDataSourceTests: XCTestCase {
    func test_처음_부르면_UUID를_만들어_저장한다() async throws {
        let storage = StubKeychainStorage()
        let local = PushLocalDataSource(storage: storage)

        let deviceID = try await local.deviceID()

        XCTAssertNotNil(UUID(uuidString: deviceID))
    }

    func test_두_번째부터는_같은_값을_준다() async throws {
        let local = PushLocalDataSource(storage: StubKeychainStorage())

        let first = try await local.deviceID()
        let second = try await local.deviceID()

        XCTAssertEqual(first, second)
    }

    func test_세션_키와_다른_키를_쓴다() async throws {
        let storage = StubKeychainStorage()
        let local = PushLocalDataSource(storage: storage)

        let first = try await local.deviceID()
        try await storage.delete(forKey: "auth-session")
        let afterSessionDelete = try await local.deviceID()

        XCTAssertEqual(first, afterSessionDelete)
    }
}
