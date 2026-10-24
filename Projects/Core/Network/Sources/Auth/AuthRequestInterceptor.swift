import Foundation
import ThirdPartyCore

/// 인증 요청에 토큰을 붙이고, 401 을 받으면 그 요청이 보낸 토큰을 세션 주인에게 넘겨 다시 보낼지 묻는다.
/// 판단과 재발급은 세션 주인이 맡는다. 여기는 상태를 갖지 않는다.
public final class AuthRequestInterceptor: RequestInterceptor, Sendable {
    private let sessionProvider: any AuthSessionProviding

    public init(sessionProvider: any AuthSessionProviding) {
        self.sessionProvider = sessionProvider
    }

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        let provider = sessionProvider
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

        // 우리가 돌려준 거절을 Alamofire 가 감싸서 다시 물어온 것이다. 세션에 또 묻지 않는다.
        if let afError = error as? AFError,
           case let .requestRetryFailed(retryError, _) = afError {
            completion(.doNotRetryWithError(retryError))
            return
        }

        if request.retryCount > 0 {
            completion(.doNotRetryWithError(NetworkError.unauthorized))
            return
        }

        // 토큰을 다시 읽지 않는다. 판단에 쓰는 것은 이 요청이 실제로 보낸 토큰이다
        let sentToken = Self.bearerToken(in: request.request)
        let provider = sessionProvider
        Task {
            switch await provider.recover(afterUnauthorized: sentToken) {
            case .retry:
                completion(.retry)
            case .fail:
                completion(.doNotRetryWithError(NetworkError.unauthorized))
            }
        }
    }

    private static func bearerToken(in request: URLRequest?) -> String? {
        let prefix = "Bearer "
        guard let value = request?.value(forHTTPHeaderField: "Authorization"),
              value.hasPrefix(prefix) else {
            return nil
        }
        let token = String(value.dropFirst(prefix.count))
        return token.isEmpty ? nil : token
    }
}
