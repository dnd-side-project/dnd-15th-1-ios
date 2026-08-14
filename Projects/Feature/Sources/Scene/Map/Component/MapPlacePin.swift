import SharedDesignSystem
import SwiftUI

// MARK: - MapPlacePinMetric

private enum MapPlacePinMetric {
    /// 물방울 바깥 크기. 피그마 Vector 28 × 31.86.
    static let width: CGFloat = 28
    static let height: CGFloat = 31.86

    static let borderWidth: CGFloat = 1
    static let shadowOpacity: CGFloat = 0.1
    static let shadowRadius: CGFloat = 2
    static let shadowOffsetY: CGFloat = 1

    /// 머리 원 중심. 원 지름이 곧 폭이라 위에서 폭의 절반만큼 내려온 자리다.
    /// 안에 드는 셋(흰 원 · 하트 · 번호)은 모두 여기에 놓인다.
    static let headCenterY: CGFloat = width / 2

    /// 선택한 장소의 흰 원. 지름 10.
    static let dotDiameter: CGFloat = 10

    /// 코스 후보의 흰 하트. 시안 잉크 크기는 14 × 12.6 다.
    ///
    /// `heart.svg` 는 24 × 24 캔버스에 잉크가 20.01 × 18.01 로 가운데 들어 있다.
    /// `resizable()` 은 투명 여백까지 함께 늘리므로 프레임에 14 × 12.6 을 그대로 주면
    /// 잉크가 그만큼 작아진다. 잉크가 시안 크기가 되도록 캔버스 비율로 되돌린 값이다.
    /// 24 × 14 / 20.01 = 16.79, 24 × 12.6 / 18.01 = 16.79 로 가로세로가 같아진다.
    static let heartSide: CGFloat = 16.79

    /// 번호가 드는 알약. 머리 원 안에 top 4 로 앉는다.
    static let numberWidth: CGFloat = 24
    static let numberHeight: CGFloat = 20
    static let numberTopInset: CGFloat = 4

    /// 흰 원 · 하트를 머리 원 중심에 놓기 위한 프레임 중심 기준 세로 이동량.
    static var contentOffsetY: CGFloat {
        headCenterY - height / 2
    }

    /// 알약을 top 4 에 놓았을 때 프레임 중심 기준 세로 이동량.
    /// 계산하면 `contentOffsetY` 와 같은 값이다. 알약도 머리 원 정중앙에 앉는다.
    static var numberOffsetY: CGFloat {
        numberTopInset + numberHeight / 2 - height / 2
    }
}

// MARK: - MapPlacePinContent

/// 물방울 안에 드는 것. 시안에 나오는 종류는 셋뿐이다.
///
/// - `selected`: 지도에서 고른 장소. 흰 원.
/// - `candidate`: 코스에 담을 후보로 고른 장소. 흰 하트.
/// - `number`: 코스에 담긴 순서. 흰 번호.
public enum MapPlacePinContent {
    case selected
    case candidate
    case number(Int)
}

// MARK: - MapPlacePin

/// 지도 위 장소 마커. 아래가 뾰족한 빨강 물방울이다.
///
/// 흰 테두리와 옅은 그림자를 달아 지도 위에서 떠 보인다. 위치는 잡지 않는다.
/// 뾰족한 끝이 좌표를 가리키므로 얹는 쪽에서 아래 끝을 기준으로 맞춘다.
///
/// 저장한 장소를 카테고리별로 찍는 마커는 이 부품이 아니다.
/// `Image.pinFood` · `pinCafe` · `pinShopping` · `pinActivity` · `pinTourism` ·
/// `pinAccommodation` · `pinConvenience` 완성 에셋을 그대로 쓴다.
///
/// 리스트 행 우측의 번호 원도 이 부품이 아니다. `PlaceNumberBadge` 를 쓴다.
///
/// ```swift
/// MapPlacePin(content: .selected)
/// MapPlacePin(content: .candidate)
/// MapPlacePin(content: .number(1))
/// ```
public struct MapPlacePin: View {
    private let content: MapPlacePinContent

    public init(content: MapPlacePinContent) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            droplet
            label
        }
        .frame(width: MapPlacePinMetric.width, height: MapPlacePinMetric.height)
    }
}

// MARK: - Layer

private extension MapPlacePin {

    var droplet: some View {
        MapPlacePinShape()
            .fill(Color.brandPrimary)
            .overlay {
                MapPlacePinShape()
                    .strokeBorder(Color.commonWhite, lineWidth: MapPlacePinMetric.borderWidth)
            }
            .shadow(
                color: Color.commonBlack.opacity(MapPlacePinMetric.shadowOpacity),
                radius: MapPlacePinMetric.shadowRadius,
                y: MapPlacePinMetric.shadowOffsetY
            )
    }

    @ViewBuilder
    var label: some View {
        switch content {
        case .selected:
            Circle()
                .fill(Color.commonWhite)
                .frame(
                    width: MapPlacePinMetric.dotDiameter,
                    height: MapPlacePinMetric.dotDiameter
                )
                .offset(y: MapPlacePinMetric.contentOffsetY)

        case .candidate:
            Image.heart
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: MapPlacePinMetric.heartSide,
                    height: MapPlacePinMetric.heartSide
                )
                .foregroundStyle(Color.commonWhite)
                .offset(y: MapPlacePinMetric.contentOffsetY)

        case let .number(number):
            // 알약 바탕은 물방울과 같은 빨강이라 눈에 띄지 않는다. 자리를 잡아 주는 값이다.
            // 가로는 물방울 축에 맞춘다. 시안에서 숫자 중심이 물방울 중심과 같았다.
            Text("\(number)")
                .typography(.body1SB)
                .foregroundStyle(Color.textInverse)
                .frame(
                    width: MapPlacePinMetric.numberWidth,
                    height: MapPlacePinMetric.numberHeight
                )
                .background(Color.brandPrimary, in: Capsule())
                .offset(y: MapPlacePinMetric.numberOffsetY)
        }
    }
}

// MARK: - MapPlacePinShape

/// 위는 원, 아래는 그 원에 접하는 두 직선이 만나 뾰족해지는 물방울.
///
/// 원 지름이 곧 폭이고 남는 높이가 꼬리 길이다. 시안 `b06` · `c01` 의 실루엣(26 × 30)과 맞춰 확인했다.
private struct MapPlacePinShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = box.width / 2
        let center = CGPoint(x: box.midX, y: box.minY + radius)
        let tip = CGPoint(x: box.midX, y: box.maxY)
        let tailLength = tip.y - center.y

        // 꼬리가 없을 만큼 납작하면 그냥 원이다
        guard tailLength > radius else { return Path(ellipseIn: box) }

        // 접점은 중심에서 이 각도만큼 아래로 벌어진 자리에 있다
        let tangentAngle = asin(radius / tailLength)

        var path = Path()
        path.move(to: tip)
        // 왼쪽 접점에서 위를 돌아 오른쪽 접점까지. 남은 두 변은 닫으면서 그려진다
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(.pi - tangentAngle),
            endAngle: .radians(2 * .pi + tangentAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Preview

private struct MapPlacePinPreviewHost: View {
    var background: Color = .gray200
    let contents: [MapPlacePinContent]
    var showsSavedPlaceMarker: Bool = false

    var body: some View {
        // 지도 자리. SDK 를 붙이지 않는다
        ZStack {
            background

            HStack(spacing: Spacing.s24) {
                ForEach(Array(contents.enumerated()), id: \.offset) { _, content in
                    MapPlacePin(content: content)
                }

                if showsSavedPlaceMarker {
                    // 이 부품이 아닌 저장한 장소 마커. 완성 에셋을 그대로 쓴다
                    Image.pinFood
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
        }
        .frame(height: 160)
    }
}

// a03 · a06 — 지도에서 고른 장소
#Preview("선택한 장소") {
    MapPlacePinPreviewHost(contents: [.selected])
}

// b06 — 코스에 담을 후보로 고른 장소
#Preview("코스 후보") {
    MapPlacePinPreviewHost(contents: [.candidate])
}

// c01 — 코스에 담긴 순서
#Preview("코스 순서") {
    MapPlacePinPreviewHost(contents: [.number(1), .number(2), .number(3)])
}

// 셋을 나란히. 오른쪽 끝은 비교용 저장한 장소 마커다
// 흰 테두리와 그림자가 보이는지 어두운 바닥에서도 본다
#Preview("셋 나란히") {
    VStack(spacing: 0) {
        MapPlacePinPreviewHost(
            contents: [.selected, .candidate, .number(1)],
            showsSavedPlaceMarker: true
        )

        MapPlacePinPreviewHost(
            background: .gray700,
            contents: [.selected, .candidate, .number(1)],
            showsSavedPlaceMarker: true
        )
    }
}
