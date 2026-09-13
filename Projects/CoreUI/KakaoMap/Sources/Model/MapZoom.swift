import CoreGraphics
import Foundation
import SharedUtils

/// 코스 결과 화면이 쓰는 줌 계산.
///
/// 지도 SDK 없이 도는 순수 계산이다.
/// KakaoMapsSDK 의 zoomLevel 은 웹 메르카토르 z 와 같은 뜻이다 — 한 단계 오르면 축척이 두 배다.
public enum MapZoom {

    /// 더 줌아웃하지 않는 바닥. 여기 닿으면 일부 장소가 화면 밖에 남는다
    public static let lowerBound = 6

    /// `KakaoMapView` 가 시트 윗면에 초점을 두는 비율. 그 값은 private 이라 여기서 쓴다
    public static let mapFocusRatio: CGFloat = 0.65

    /// 지도 타일 한 장의 픽셀 크기
    private static let tileSize: Double = 256

    /// anchor 를 `focusRatio` 자리에 둔 채, 모든 좌표가 보이는 영역에 들어오는 가장 큰 줌.
    ///
    /// 기본 `focusRatio` 0.5 는 한가운데다. 남북은 초점 위·아래 여유를 따로 잰다.
    /// 코스 한가운데를 중심으로 잡는 것보다 더 많이 줌아웃한다. 그 대가는 스펙 2절이 적었다.
    ///
    /// - Parameters:
    ///   - viewWidth: 지도 뷰의 가로 픽셀
    ///   - visibleHeight: 시트 위에 보이는 세로 픽셀. 화면 전체가 아니다
    ///   - maximum: 이보다 더 당기지 않는다
    ///   - minimum: 이보다 더 밀지 않는다
    ///   - focusRatio: 보이는 띠 맨 위가 0, 맨 아래가 1. 기본은 한가운데
    public static func fit(
        coordinates: [Coordinate],
        anchor: Coordinate,
        viewWidth: CGFloat,
        visibleHeight: CGFloat,
        maximum: Int,
        minimum: Int = lowerBound,
        focusRatio: CGFloat = 0.5
    ) -> Int {
        guard maximum >= minimum else { return maximum }
        guard viewWidth > 0, visibleHeight > 0 else { return maximum }
        guard focusRatio > 0, focusRatio < 1 else { return maximum }

        var west: Double = 0
        var east: Double = 0
        var north: Double = 0
        var south: Double = 0
        let anchorPoint = normalized(anchor)

        for coordinate in coordinates {
            let point = normalized(coordinate)
            let dx = point.x - anchorPoint.x
            let dy = point.y - anchorPoint.y
            if dx >= 0 { east = max(east, dx) } else { west = max(west, -dx) }
            if dy >= 0 { south = max(south, dy) } else { north = max(north, -dy) }
        }

        guard west > 0 || east > 0 || north > 0 || south > 0 else { return maximum }

        // 정규 좌표 1.0 이 곧 세계 한 바퀴다. 줌 z 에서 세계는 tileSize * 2^z 픽셀이다
        let spanX = max(west, east) * 2
        let spanY = max(north / Double(focusRatio), south / Double(1 - focusRatio))

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
