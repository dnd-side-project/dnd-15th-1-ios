import SharedUtils
import ThirdParty

@DependencyClient
public struct LocationClient: Sendable {
    /// 지금 권한 상태를 읽는다. 시스템 창을 띄우지 않는다
    public var authorization: @Sendable () async -> LocationAuthorization = { .notDetermined }
    /// 미결정일 때만 시스템 권한 창을 띄우고, 사용자가 고른 뒤의 상태를 돌려준다.
    /// 이미 정해진 상태면 창 없이 그 상태를 그대로 돌려준다
    public var requestAuthorization: @Sendable () async -> LocationAuthorization = { .notDetermined }
    /// 좌표를 한 번 읽는다. 따라다니지 않는다
    public var currentCoordinate: @Sendable () async throws -> Coordinate
    /// 내 위치를 계속 흘린다. 권한을 요청하지 않는다.
    /// 쓸 수 있는 좌표면 그 값을, 권한이 없거나 대략적 위치면 `nil` 을 보낸다. 구독을 끊으면 갱신이 멈춘다
    public var coordinateUpdates: @Sendable () -> AsyncStream<Coordinate?> = { AsyncStream { $0.finish() } }
}

extension LocationClient: TestDependencyKey {
    public static let testValue = LocationClient()
}

public extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}
