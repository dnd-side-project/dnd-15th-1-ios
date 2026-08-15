import Domain
import Foundation

public struct MapMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: Coordinate
    public let kind: Kind

    public enum Kind: Equatable, Sendable {
        case place
        /// 코스 번호 핀 ①②③
        case numbered(Int)
        case selected
    }

    public init(id: String, coordinate: Coordinate, kind: Kind) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
    }
}
