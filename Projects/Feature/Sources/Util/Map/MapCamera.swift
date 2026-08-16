import Domain
import Foundation

public struct MapCamera: Equatable, Sendable {
    public var center: Coordinate
    /// KakaoMapsSDK zoomLevel. 클수록 확대
    public var zoomLevel: Int

    public init(center: Coordinate, zoomLevel: Int) {
        self.center = center
        self.zoomLevel = zoomLevel
    }
}

public extension MapCamera {
    /// 시안 지도 배경과 같은 안산 반월역 일대
    static let ansan = MapCamera(
        center: Coordinate(latitude: 37.3116, longitude: 126.9022),
        zoomLevel: 14
    )
}
