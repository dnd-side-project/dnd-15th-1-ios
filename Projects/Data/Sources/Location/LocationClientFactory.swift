import Domain
import Foundation

public enum LocationClientFactory {
    /// - Parameter timeout: 좌표 1회 조회의 시간 상한. 넘으면 `LocationError.unavailable` 이다
    @MainActor
    public static func make(timeout: Duration = .seconds(5)) -> LocationClient {
        let provider = SystemLocationProvider()
        return LocationClient(
            authorization: { await provider.authorization() },
            requestAuthorization: { await provider.requestAuthorization() },
            currentCoordinate: { try await provider.currentCoordinate(timeout: timeout) }
        )
    }
}
