import Foundation
import SharedUtils

/// 서버가 도보 30분 이상 구간에만 함께 주는 대중교통 경로의 합계.
/// 요금·환승·정류장·노선은 화면이 안 쓰므로 담지 않는다
public struct CourseTransit: Equatable, Sendable {
    public let minutes: Int
    public let distanceMeters: Int
    /// 대중교통 구간들의 좌표를 이동 순서대로 이어 붙인 것. 서버가 좌표를 못 주면 빈 배열
    public let path: [Coordinate]

    public init(minutes: Int, distanceMeters: Int, path: [Coordinate]) {
        self.minutes = minutes
        self.distanceMeters = distanceMeters
        self.path = path
    }
}
