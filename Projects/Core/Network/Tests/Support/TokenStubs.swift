import CoreNetwork
import Foundation

actor StubTokenProvider: TokenProviding {
    private(set) var token: String?
    private(set) var generation = 0

    init(token: String? = "access-token") {
        self.token = token
    }

    func accessToken() async throws -> String? {
        token
    }

    func setToken(_ token: String?) {
        self.token = token
        generation += 1
    }
}

actor StubTokenRefresher: TokenRefreshing {
    private(set) var refreshCount = 0
    private var error: Error?
    private var delayNanoseconds: UInt64 = 0
    private let provider: StubTokenProvider?
    private let nextToken: String?

    init(
        provider: StubTokenProvider? = nil,
        nextToken: String? = "access-token-refreshed"
    ) {
        self.provider = provider
        self.nextToken = nextToken
    }

    func setError(_ error: Error?) {
        self.error = error
    }

    func setDelayNanoseconds(_ value: UInt64) {
        delayNanoseconds = value
    }

    func refresh() async throws {
        refreshCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error {
            throw error
        }
        if let provider, let nextToken {
            await provider.setToken(nextToken)
        }
    }
}

/// `URLProtocolStub.requestHandler` 안에서 토큰을 바꿀 수 있게 동기 세터를 둔다.
final class SyncTokenProvider: TokenProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedToken: String?

    init(token: String?) {
        storedToken = token
    }

    func accessToken() async throws -> String? {
        lock.withLock { storedToken }
    }

    func setToken(_ token: String?) {
        lock.withLock { storedToken = token }
    }
}
