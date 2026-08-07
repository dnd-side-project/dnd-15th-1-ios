import Foundation
import ThirdPartyCore

public struct AFNetworkClient: NetworkClient, Sendable {
    private let session: Session
    private let configuration: NetworkConfiguration

    public init(session: Session, configuration: NetworkConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    public static func plain(
        configuration: NetworkConfiguration,
        session: Session? = nil
    ) -> AFNetworkClient {
        let resolved = session ?? NetworkSessionFactory.plain(configuration: configuration)
        return AFNetworkClient(session: resolved, configuration: configuration)
    }

    public static func authed(
        configuration: NetworkConfiguration,
        tokenProvider: any TokenProviding,
        tokenRefresher: any TokenRefreshing
    ) -> AFNetworkClient {
        AFNetworkClient(
            session: NetworkSessionFactory.authed(
                configuration: configuration,
                tokenProvider: tokenProvider,
                tokenRefresher: tokenRefresher
            ),
            configuration: configuration
        )
    }

    public func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        let data = try await perform(endpoint)
        do {
            return try configuration.jsonDecoder.decode(T.self, from: data)
        } catch {
            NetworkLog.error(error, url: nil)
            throw NetworkError.decodingFailed
        }
    }

    public func request(_ endpoint: some APIEndpoint) async throws {
        _ = try await perform(endpoint)
    }

    private func perform(_ endpoint: some APIEndpoint) async throws -> Data {
        let urlRequest = try makeURLRequest(for: endpoint)
        NetworkLog.request(urlRequest)
        let started = Date()

        let dataRequest = session.request(urlRequest).validate(statusCode: 200..<300)
        let response = await dataRequest.serializingData().response
        let durationMs = Int(Date().timeIntervalSince(started) * 1000)

        if let transport = response.error,
           response.response == nil,
           response.data == nil {
            if let networkError = Self.extractNetworkError(from: transport) {
                throw networkError
            }
            NetworkLog.error(transport, url: urlRequest.url)
            throw NetworkError.transport(message: transport.localizedDescription)
        }

        if let http = response.response {
            let data = response.data ?? Data()
            NetworkLog.response(
                statusCode: http.statusCode,
                url: urlRequest.url,
                data: data,
                durationMs: durationMs
            )

            guard (200...299).contains(http.statusCode) else {
                throw mapStatusCode(http.statusCode, data: data)
            }
            return data
        }

        if let underlying = response.error {
            if let networkError = Self.extractNetworkError(from: underlying) {
                throw networkError
            }
            NetworkLog.error(underlying, url: urlRequest.url)
            throw NetworkError.transport(message: underlying.localizedDescription)
        }

        let error = NetworkError.invalidResponse
        NetworkLog.error(error, url: urlRequest.url)
        throw error
    }

    private func makeURLRequest(for endpoint: some APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(normalizedPath(endpoint.path)),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        if endpoint.queryItems.isEmpty == false {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func normalizedPath(_ path: String) -> String {
        path.hasPrefix("/") ? String(path.dropFirst()) : path
    }

    private func mapStatusCode(_ statusCode: Int, data: Data) -> NetworkError {
        let message = try? configuration.jsonDecoder
            .decode(ErrorMessageDTO.self, from: data)
            .message
        switch statusCode {
        case 400:
            return .badRequest(message: message)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden(message: message)
        case 404:
            return .notFound(message: message)
        case 409:
            return .conflict(message: message)
        case 400...499:
            return .clientError(statusCode: statusCode, message: message)
        default:
            return .serverError(statusCode: statusCode, message: message)
        }
    }

    private static func extractNetworkError(from error: Error) -> NetworkError? {
        var current: Error? = error
        var depth = 0
        while let err = current, depth < 8 {
            if let networkError = err as? NetworkError {
                return networkError
            }
            if let networkError = NetworkError.fromNSError(err as NSError) {
                return networkError
            }

            if let afError = err as? AFError ?? err.asAFError {
                switch afError {
                case let .requestAdaptationFailed(underlying):
                    current = underlying
                case let .requestRetryFailed(retryError, originalError):
                    if let networkError = extractNetworkError(from: retryError) {
                        return networkError
                    }
                    current = originalError
                case let .sessionTaskFailed(error):
                    current = error
                default:
                    current = afError.underlyingError
                }
            } else if let underlying = (err as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                current = underlying
            } else {
                break
            }
            depth += 1
        }
        return nil
    }
}
