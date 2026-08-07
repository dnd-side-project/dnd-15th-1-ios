import Foundation
import ThirdPartyCore

public final class AuthRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    private let tokenProvider: any TokenProviding
    private let tokenRefresher: any TokenRefreshing
    private let lock = NSLock()
    private var refreshTask: Task<Void, Error>?

    public init(
        tokenProvider: any TokenProviding,
        tokenRefresher: any TokenRefreshing
    ) {
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
    }

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        let provider = tokenProvider
        let request = urlRequest
        Task {
            do {
                var adapted = request
                if let token = try await provider.accessToken(), token.isEmpty == false {
                    guard adapted.url?.scheme?.lowercased() == "https" else {
                        throw NetworkError.invalidURL
                    }
                    adapted.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                completion(.success(adapted))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: any Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        let statusCode = request.response?.statusCode
        guard statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        if request.retryCount > 0 {
            completion(.doNotRetryWithError(NetworkError.unauthorized))
            return
        }

        let interceptor = self
        Task {
            do {
                try await interceptor.refreshSingleFlight()
                completion(.retry)
            } catch {
                completion(.doNotRetryWithError(NetworkError.unauthorized))
            }
        }
    }

    private func refreshSingleFlight() async throws {
        let existing: Task<Void, Error>? = lock.withLock { refreshTask }
        if let existing {
            try await existing.value
            return
        }

        let refresher = tokenRefresher
        let task = Task {
            do {
                try await refresher.refresh()
            } catch {
                throw NetworkError.unauthorized
            }
        }
        lock.withLock { refreshTask = task }

        do {
            try await task.value
            lock.withLock { refreshTask = nil }
        } catch {
            lock.withLock { refreshTask = nil }
            throw error
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
