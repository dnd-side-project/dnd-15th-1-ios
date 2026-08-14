import Domain
import Foundation

public struct MapRoute: Equatable, Identifiable, Sendable {
    public let id: String
    /// 그리는 순서 그대로
    public let coordinates: [Coordinate]

    public init(id: String, coordinates: [Coordinate]) {
        self.id = id
        self.coordinates = coordinates
    }
}
