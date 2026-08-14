import Foundation

/// 구간 이동 값. 서버가 계산해서 내려준다. 클라이언트는 추정하지 않는다.
public struct CourseLeg: Equatable, Sendable {
    public let walkingMinutes: Int
    public let distanceMeters: Int

    public init(walkingMinutes: Int, distanceMeters: Int) {
        self.walkingMinutes = walkingMinutes
        self.distanceMeters = distanceMeters
    }
}
