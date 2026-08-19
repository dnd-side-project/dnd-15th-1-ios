import Foundation
import ThirdPartyCore

public final class AuthRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    private let tokenProvider: any TokenProviding
    private let tokenRefresher: any TokenRefreshing
    private let lock = NSLock()
    private var refreshTask: Task<Void, Error>?
    private var failedAccessToken: String?

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

        // 우리가 돌려준 거절을 Alamofire 가 감싸서 다시 물어온 것이다. 재발급을 또 하지 않는다.
        if let afError = error as? AFError,
           case let .requestRetryFailed(retryError, _) = afError {
            completion(.doNotRetryWithError(retryError))
            return
        }

        if request.retryCount > 0 {
            completion(.doNotRetryWithError(NetworkError.unauthorized))
            return
        }

        let sentAuthorization = request.request?.value(forHTTPHeaderField: "Authorization")
        let interceptor = self
        Task {
            let currentToken = try? await interceptor.tokenProvider.accessToken()

            // 내가 보낸 토큰이 이미 갱신됐다. 재발급 없이 그대로 다시 보낸다.
            if let currentToken,
               currentToken.isEmpty == false,
               "Bearer \(currentToken)" != sentAuthorization {
                completion(.retry)
                return
            }

            // 이 토큰으로는 방금 재발급이 실패했다. 같은 요청을 또 낼 이유가 없다.
            if interceptor.isKnownFailed(currentToken) {
                completion(.doNotRetryWithError(NetworkError.unauthorized))
                return
            }

            do {
                try await interceptor.refreshSingleFlight(startedWith: currentToken)
                completion(.retry)
            } catch {
                completion(.doNotRetryWithError(NetworkError.unauthorized))
            }
        }
    }

    private func isKnownFailed(_ token: String?) -> Bool {
        lock.withLock {
            guard let failedAccessToken, let token else { return false }
            return failedAccessToken == token
        }
    }

    private func refreshSingleFlight(startedWith token: String?) async throws {
        let refresher = tokenRefresher
        let (task, isOwner): (Task<Void, Error>, Bool) = lock.withLock {
            if let existing = refreshTask {
                return (existing, false)
            }

            let newTask = Task {
                try await refresher.refresh()
            }
            refreshTask = newTask
            return (newTask, true)
        }

        do {
            try await task.value
            if isOwner {
                // Only the creator clears. New tasks are created only while refreshTask is nil,
                // so owner cleanup cannot wipe a newer flight.
                lock.withLock {
                    refreshTask = nil
                    failedAccessToken = nil
                }
            }
        } catch {
            if isOwner {
                // 전송 실패까지 기억하면 회복이 막힌다. 기억을 지우는 길이 재발급 성공뿐이기 때문이다.
                let isAuthenticationFailure = (error as? NetworkError) == .unauthorized
                lock.withLock {
                    refreshTask = nil
                    failedAccessToken = isAuthenticationFailure ? token : nil
                }
            }
            throw NetworkError.unauthorized
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
