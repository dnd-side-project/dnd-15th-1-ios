import CoreKakaoMap
import Domain
import SharedDesignSystem
import SwiftUI
import UIKit

/// 마커 종류를 지도가 받는 핀으로 바꾼다.
///
/// 지도 모듈은 장소 카테고리도 코스 번호도 모른다. 그 앎이 여기 있다
@MainActor
enum MapMarkerStyle {

    /// 저장한 장소 핀. 에셋 상자 24 안에 흰 원 20 · 컬러 원 16 이 들어 있고
    /// 남는 자리는 SVG 에 구워진 그림자 몫이다. 상자를 줄이면 안쪽 원도 같이 줄어
    /// 시안과 어긋난다. 그래서 원본 크기 그대로 쓴다
    private static let categoryPinSide: CGFloat = 24

    /// 그림자 radius 2 + offsetY 1 을 담는 여백
    private static let pinShadowInset: CGFloat = 4

    /// 물방울 높이. `MapPlacePin` 의 피그마 Vector 28 × 31.86 에서 온 값이다
    private static let pinHeight: CGFloat = 31.86

    private static let placeColor = UIColor(red: 0.98, green: 0.31, blue: 0.44, alpha: 1.0)

    static func pin(for marker: MapMarker) -> MapPin {
        let kind = marker.kind
        return MapPin(
            id: marker.id,
            coordinate: marker.coordinate,
            styleID: styleID(for: kind),
            rank: rank(for: kind),
            makeStyle: {
                MapPinStyle(
                    image: image(for: kind),
                    anchorPoint: anchorPoint(for: kind)
                )
            }
        )
    }

    static func styleID(for kind: MapMarker.Kind) -> String {
        switch kind {
        case .place: "dulpick.map.style.place"
        case .selected: "dulpick.map.style.selected"
        case let .numbered(number): "dulpick.map.style.numbered.\(number)"
        case let .category(category): "dulpick.map.style.category.\(category.rawValue)"
        case .candidate: "dulpick.map.style.candidate"
        }
    }

    static func image(for kind: MapMarker.Kind) -> UIImage {
        switch kind {
        case .place:
            MapPinImage.circle(diameter: 22, fill: placeColor)
        case .selected:
            MapPinImage.rendered(MapPlacePin(content: .selected), padding: pinShadowInset)
        case let .numbered(number):
            MapPinImage.rendered(MapPlacePin(content: .number(number)), padding: pinShadowInset)
        case let .category(category):
            MapPinImage.resized(category.pin, to: categoryPinSide)
        case .candidate:
            MapPinImage.rendered(MapPlacePin(content: .candidate), padding: pinShadowInset)
        }
    }

    /// 같은 자리의 카테고리·장소 배지 위에 고른 핀이 앉는다. 큰 쪽이 위다
    static func rank(for kind: MapMarker.Kind) -> Int {
        switch kind {
        case .place, .category:
            0
        case .numbered, .selected, .candidate:
            1
        }
    }

    /// 마커 이미지의 어느 점이 좌표에 놓이는지.
    ///
    /// 원형 마커는 중심이 좌표다. 물방울은 뾰족한 아래 끝이 좌표다
    static func anchorPoint(for kind: MapMarker.Kind) -> CGPoint {
        switch kind {
        case .selected, .candidate, .numbered:
            // 그림자 여백만큼 이미지가 커졌다. 1.0 을 주면 끝이 좌표보다 그만큼 위에 앉는다
            CGPoint(x: 0.5, y: (pinShadowInset + pinHeight) / (pinShadowInset * 2 + pinHeight))
        // default 를 쓰지 않는다. 물방울 심볼이 늘면 여기서 컴파일이 막혀야 한다
        case .place, .category:
            CGPoint(x: 0.5, y: 0.5)
        }
    }
}

#if DEBUG
/// `MapView` 프리뷰가 안 쓰는 표면(번호 핀·선택 핀·경로선·현재위치)까지 한 번에 보여준다.
#Preview("코스 마커 + 경로") {
    @Previewable @State var camera: MapCamera = .seoulCityHall

    let places = SavedPlace.mocks.prefix(4)

    KakaoMapPreviewContainer {
        KakaoMapView(
            camera: $camera,
            pins: places.enumerated().map { index, saved in
                MapMarkerStyle.pin(
                    for: MapMarker(
                        id: saved.id,
                        coordinate: saved.place.coordinate,
                        kind: index == 0 ? .selected : .numbered(index + 1)
                    )
                )
            },
            routes: [
                MapRoute(id: "preview.course", coordinates: places.map(\.place.coordinate)),
            ],
            userLocation: MapCamera.seoulCityHall.center
        )
        .ignoresSafeArea()
    }
}
#endif
