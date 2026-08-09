import Foundation
import ThirdPartyCore

public enum NetworkClientFactory {
    public static func plain(
        config: NetworkConfiguration,
        session: Session? = nil
    ) -> AFNetworkClient {
        let resolved = session ?? makeSession(timeout: config.timeout)
        return AFNetworkClient(
            session: resolved,
            baseURL: config.baseURL,
            jsonDecoder: config.jsonDecoder
        )
    }

    public static func authed(
        config: NetworkConfiguration,
        tokenProvider: any TokenProviding,
        tokenRefresher: any TokenRefreshing
    ) -> AFNetworkClient {
        let interceptor = AuthRequestInterceptor(
            tokenProvider: tokenProvider,
            tokenRefresher: tokenRefresher
        )
        return AFNetworkClient(
            session: makeSession(timeout: config.timeout, interceptor: interceptor),
            baseURL: config.baseURL,
            jsonDecoder: config.jsonDecoder
        )
    }

    private static func makeSession(
        timeout: TimeInterval,
        interceptor: RequestInterceptor? = nil
    ) -> Session {
        let sessionConfig = URLSessionConfiguration.af.default
        sessionConfig.timeoutIntervalForRequest = timeout
        return Session(configuration: sessionConfig, interceptor: interceptor)
    }
}
