import Foundation

/// 구간을 무엇으로 이동하는지. 버스·지하철·둘 다 `transit` 하나다
public enum CourseTravelMode: Equatable, Sendable {
    case walking
    case transit
}
