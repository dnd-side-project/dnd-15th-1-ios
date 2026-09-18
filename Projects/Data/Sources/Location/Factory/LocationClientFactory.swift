import Domain
import Foundation

public enum LocationClientFactory {
    /// - Parameter timeout: 좌표 1회 조회의 시간 상한. 넘으면 `LocationError.unavailable` 이다
    /// - Parameter maxCacheAge: 캐시 좌표를 바로 쓸 수 있는 최대 나이. 넘으면 새로 잰다
    @MainActor
    public static func make(
        timeout: Duration = .seconds(5),
        maxCacheAge: Duration = .seconds(10)
    ) -> LocationClient {
        let provider = SystemLocationProvider(maxCacheAge: maxCacheAge)
        return LocationClient(
            authorization: { await provider.authorization() },
            requestAuthorization: { await provider.requestAuthorization() },
            currentCoordinate: { try await provider.currentCoordinate(timeout: timeout) }
        )
    }
}
