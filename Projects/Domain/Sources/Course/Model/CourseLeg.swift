import Foundation
import SharedUtils

/// 구간 이동 값. 서버가 계산해서 내려준다. 클라이언트는 추정하지 않는다.
///
/// 서버의 도보 값·도보 경로·대중교통 값을 모두 담는다.
/// 화면에 보일 값은 `travel*` 프로퍼티가 정한다. 대중교통이 있으면 대중교통이다
public struct CourseLeg: Equatable, Sendable {
    public let walkingMinutes: Int
    /// 도보 거리
    public let distanceMeters: Int
    /// 도보 경로 좌표. 서버가 못 주면 빈 배열
    public let walkingPath: [Coordinate]
    /// 도보 30분 이상 구간에만 온다. 해당하지 않거나 조회에 실패하면 nil
    public let transit: CourseTransit?

    public init(
        walkingMinutes: Int,
        distanceMeters: Int,
        walkingPath: [Coordinate] = [],
        transit: CourseTransit? = nil
    ) {
        self.walkingMinutes = walkingMinutes
        self.distanceMeters = distanceMeters
        self.walkingPath = walkingPath
        self.transit = transit
    }
}

// 서버는 대중교통을 걷는 것보다 나은 구간에만 준다. 그래서 오면 대중교통만 보인다
public extension CourseLeg {
    var travelMode: CourseTravelMode { transit == nil ? .walking : .transit }

    var travelMinutes: Int { transit?.minutes ?? walkingMinutes }

    var travelDistanceMeters: Int { transit?.distanceMeters ?? distanceMeters }

    /// 대중교통 경로가 비어도 도보 경로로 바꾸지 않는다. 행의 수단과 다른 길을 그리지 않는다
    var travelPath: [Coordinate] { transit?.path ?? walkingPath }
}
