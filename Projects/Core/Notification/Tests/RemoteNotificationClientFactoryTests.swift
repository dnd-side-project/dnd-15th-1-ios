@testable import CoreNotification
import XCTest

@MainActor
final class RemoteNotificationClientFactoryTests: XCTestCase {
    func test_팩토리는_부를_때마다_새_인스턴스를_준다() {
        let factory = RemoteNotificationClientFactory()

        let first = factory.make()
        let second = factory.make()

        XCTAssertFalse(first === second)
    }
}
