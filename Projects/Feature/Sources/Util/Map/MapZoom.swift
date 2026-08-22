import CoreGraphics
import Domain
import Foundation

/// 코스 결과 화면이 쓰는 줌 계산.
///
/// 지도 SDK 없이 도는 순수 계산이다. `Cycle 5` 가 코스 결과 화면에서 `DulpickMapView` 를 통해 부른다. 이 Cycle 에는 부르는 곳이 없다.
/// KakaoMapsSDK 의 zoomLevel 은 웹 메르카토르 z 와 같은 뜻이다 — 한 단계 오르면 축척이 두 배다.
enum MapZoom {

    /// 더 줌아웃하지 않는 바닥. 여기 닿으면 일부 장소가 화면 밖에 남는다
    static let lowerBound = 6

    /// 지도 타일 한 장의 픽셀 크기
    private static let tileSize: Double = 256

    /// anchor 를 화면 한가운데에 둔 채, 모든 좌표가 보이는 영역에 들어오는 가장 큰 줌.
    ///
    /// anchor 가 중심이므로 반지름은 anchor 에서 가장 먼 점까지다.
    /// 코스 한가운데를 중심으로 잡는 것보다 더 많이 줌아웃한다. 그 대가는 스펙 2절이 적었다.
    ///
    /// - Parameters:
    ///   - viewWidth: 지도 뷰의 가로 픽셀
    ///   - visibleHeight: 시트 위에 보이는 세로 픽셀. 화면 전체가 아니다
    ///   - maximum: 이보다 더 당기지 않는다
    ///   - minimum: 이보다 더 밀지 않는다
    static func fit(
        coordinates: [Coordinate],
        anchor: Coordinate,
        viewWidth: CGFloat,
        visibleHeight: CGFloat,
        maximum: Int,
        minimum: Int = lowerBound
    ) -> Int {
        guard maximum >= minimum else { return maximum }
        guard viewWidth > 0, visibleHeight > 0 else { return maximum }

        // anchor 가 한가운데라 담아야 할 폭은 가장 먼 점까지의 두 배다
        var halfSpanX: Double = 0
        var halfSpanY: Double = 0
        let anchorPoint = normalized(anchor)

        for coordinate in coordinates {
            let point = normalized(coordinate)
            halfSpanX = max(halfSpanX, abs(point.x - anchorPoint.x))
            halfSpanY = max(halfSpanY, abs(point.y - anchorPoint.y))
        }

        guard halfSpanX > 0 || halfSpanY > 0 else { return maximum }

        // 정규 좌표 1.0 이 곧 세계 한 바퀴다. 줌 z 에서 세계는 tileSize * 2^z 픽셀이다
        let spanX = halfSpanX * 2
        let spanY = halfSpanY * 2

        var best = minimum
        for level in stride(from: maximum, through: minimum, by: -1) {
            let worldPixels = tileSize * pow(2, Double(level))
            let fitsWidth = spanX * worldPixels <= Double(viewWidth)
            let fitsHeight = spanY * worldPixels <= Double(visibleHeight)
            if fitsWidth, fitsHeight {
                best = level
                break
            }
        }
        return best
    }

    /// 웹 메르카토르 정규 좌표. 둘 다 0...1 이다
    private static func normalized(_ coordinate: Coordinate) -> (x: Double, y: Double) {
        let x = (coordinate.longitude + 180) / 360
        let clampedLatitude = min(max(coordinate.latitude, -85.05112878), 85.05112878)
        let radians = clampedLatitude * .pi / 180
        let y = (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
        return (x, y)
    }
}
