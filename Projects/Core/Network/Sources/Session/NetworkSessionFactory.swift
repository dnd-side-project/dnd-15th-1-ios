import Foundation
import ThirdPartyCore

public enum NetworkSessionFactory {
    public static func plain(configuration: NetworkConfiguration) -> Session {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = configuration.timeout
        return Session(configuration: config)
    }

    public static func authed(
        configuration: NetworkConfiguration,
        tokenProvider: any TokenProviding,
        tokenRefresher: any TokenRefreshing
    ) -> Session {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = configuration.timeout
        let interceptor = AuthRequestInterceptor(
            tokenProvider: tokenProvider,
            tokenRefresher: tokenRefresher
        )
        return Session(configuration: config, interceptor: interceptor)
    }
}
