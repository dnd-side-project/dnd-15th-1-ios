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

    /// 여러 장소가 한눈에 보이는 줌. 시작값이고 실기기에서 맞춘다
    static let multiPlaceZoom = 14

    /// 장소 하나를 볼 때의 줌. 시작값이고 실기기에서 맞춘다
    static let singlePlaceZoom = 16

    /// 저장한 장소가 없을 때 서는 자리. 서울 시청이다
    static let seoulCityHall = MapCamera(
        center: Coordinate(latitude: 37.5665, longitude: 126.9780),
        zoomLevel: multiPlaceZoom
    )

    /// 이 좌표를 보여 달라는 뜻이다.
    ///
    /// 화면 어디에 놓을지는 `DulpickMapView` 가 정한다. 여기서 오프셋을 걸지 않는다
    static func focusing(_ coordinate: Coordinate, zoomLevel: Int) -> MapCamera {
        MapCamera(center: coordinate, zoomLevel: zoomLevel)
    }
}
