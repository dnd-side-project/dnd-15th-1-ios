import Domain
import Foundation
import SharedUtils

public struct MapMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: Coordinate
    public let kind: Kind

    public enum Kind: Equatable, Sendable {
        case place
        /// 코스 번호 핀 ①②③
        case numbered(Int)
        case selected
        /// 저장한 장소 핀. 카테고리마다 다른 에셋을 쓴다
        case category(PlaceCategory)
        /// 코스에 담을 후보로 고른 장소. 흰 하트가 든 물방울이다 (시안 b06)
        case candidate
    }

    public init(id: String, coordinate: Coordinate, kind: Kind) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
    }
}
