@testable import CoreNotification
import XCTest

@MainActor
final class RemoteNotificationClientStreamTests: XCTestCase {
    func test_구독하면_마지막_토큰을_먼저_받는다() async {
        let client = RemoteNotificationClientFactory().make()
        client.emit(token: "token-1")

        let received = await firstValue(from: client.fcmTokenStream())

        XCTAssertEqual(received, "token-1")
    }

    func test_구독자가_둘이면_둘_다_받는다() async {
        let client = RemoteNotificationClientFactory().make()
        let stream1 = client.fcmTokenStream()
        let stream2 = client.fcmTokenStream()

        client.emit(token: "token-2")

        let first = await firstValue(from: stream1)
        let second = await firstValue(from: stream2)

        XCTAssertEqual(first, "token-2")
        XCTAssertEqual(second, "token-2")
    }

    private func firstValue(from stream: AsyncStream<String>) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                for await token in stream {
                    return token
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                return nil
            }
            let value = await group.next()
            group.cancelAll()
            switch value {
            case let .some(token):
                return token
            case .none:
                return nil
            }
        }
    }
}
