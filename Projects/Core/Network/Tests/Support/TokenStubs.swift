import CoreNetwork
import Foundation

actor StubTokenProvider: TokenProviding {
    private(set) var token: String?
    private(set) var generation = 0
    /// 토큰을 읽을 때마다 그때까지 읽은 횟수를 내보낸다.
    nonisolated let accessTokenReads: AsyncStream<Int>
    private let accessTokenReadsContinuation: AsyncStream<Int>.Continuation
    private var accessTokenReadCount = 0

    init(token: String? = "access-token") {
        self.token = token
        let reads = AsyncStream<Int>.makeStream()
        accessTokenReads = reads.stream
        accessTokenReadsContinuation = reads.continuation
    }

    func accessToken() async throws -> String? {
        accessTokenReadCount += 1
        accessTokenReadsContinuation.yield(accessTokenReadCount)
        return token
    }

    func setToken(_ token: String?) {
        self.token = token
        generation += 1
    }
}

actor StubTokenRefresher: TokenRefreshing {
    private(set) var refreshCount = 0
    /// 재발급이 시작될 때마다 그때까지 시작한 횟수를 내보낸다.
    nonisolated let refreshStarts: AsyncStream<Int>
    private let refreshStartsContinuation: AsyncStream<Int>.Continuation
    private var error: Error?
    private var isHoldingRefresh = false
    private var heldRefreshes: [CheckedContinuation<Void, Never>] = []
    private let provider: StubTokenProvider?
    private let nextToken: String?

    init(
        provider: StubTokenProvider? = nil,
        nextToken: String? = "access-token-refreshed"
    ) {
        self.provider = provider
        self.nextToken = nextToken
        let starts = AsyncStream<Int>.makeStream()
        refreshStarts = starts.stream
        refreshStartsContinuation = starts.continuation
    }

    func setError(_ error: Error?) {
        self.error = error
    }

    /// 이 뒤에 시작되는 재발급은 `releaseRefresh()` 를 부를 때까지 끝나지 않는다.
    func holdRefresh() {
        isHoldingRefresh = true
    }

    func releaseRefresh() {
        isHoldingRefresh = false
        let held = heldRefreshes
        heldRefreshes.removeAll()
        for continuation in held {
            continuation.resume()
        }
    }

    func refresh() async throws {
        refreshCount += 1
        refreshStartsContinuation.yield(refreshCount)
        if isHoldingRefresh {
            await withCheckedContinuation { heldRefreshes.append($0) }
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

/// 스트림에서 `minimum` 이상인 첫 값을 기다린다.
/// 제한 시간은 값이 오지 않을 때만 걸린다. 그때는 nil 을 돌려준다.
func firstValue(atLeast minimum: Int, from stream: AsyncStream<Int>) async -> Int? {
    await withTaskGroup(of: Int?.self) { group in
        group.addTask {
            for await value in stream where value >= minimum {
                return value
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
        case let .some(found):
            return found
        case .none:
            return nil
        }
    }
}
