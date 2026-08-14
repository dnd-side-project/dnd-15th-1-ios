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

    /// 번호가 드는 알약. 머리 원 안에 top 4 로 앉는다.
    static let numberWidth: CGFloat = 24
    static let numberHeight: CGFloat = 20
    static let numberTopInset: CGFloat = 4

    /// 카테고리 아이콘. 세로는 프레임 중심에서 1.6 위, 즉 머리 원 중심이다.
    static let categoryWidth: CGFloat = 14
    static let categoryHeight: CGFloat = 12.6
    static let categoryOffsetY: CGFloat = -1.6

    /// 알약을 top 4 에 놓았을 때 프레임 중심 기준 세로 이동량.
    static var numberOffsetY: CGFloat {
        numberTopInset + numberHeight / 2 - height / 2
    }
}

// MARK: - MapPlacePinContent

/// 핀 안에 드는 것. 지도에 그냥 찍힌 장소는 카테고리 아이콘, 코스에 담긴 장소는 순번이다.
public enum MapPlacePinContent {
    case category(Image)
    case number(Int)
}

// MARK: - MapPlacePin

/// 지도 위 장소 마커. 아래가 뾰족한 빨강 물방울이다.
///
/// 흰 테두리와 옅은 그림자를 달아 지도 위에서 떠 보인다. 위치는 잡지 않는다.
/// 뾰족한 끝이 좌표를 가리키므로 얹는 쪽에서 아래 끝을 기준으로 맞춘다.
///
/// 리스트 행 우측의 번호 원은 이 부품이 아니다. `PlaceNumberBadge` 를 쓴다.
///
/// ```swift
/// MapPlacePin(content: .category(.categoryFood))
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
        case let .category(image):
            image
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: MapPlacePinMetric.categoryWidth,
                    height: MapPlacePinMetric.categoryHeight
                )
                .foregroundStyle(Color.textInverse)
                .offset(y: MapPlacePinMetric.categoryOffsetY)

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
    let contents: [MapPlacePinContent]

    var body: some View {
        // 지도 자리. SDK 를 붙이지 않는다
        ZStack {
            Color.gray200

            HStack(spacing: Spacing.s24) {
                ForEach(Array(contents.enumerated()), id: \.offset) { _, content in
                    MapPlacePin(content: content)
                }
            }
        }
        .frame(height: 160)
    }
}

// c01 — 코스에 담긴 순서
#Preview("번호") {
    MapPlacePinPreviewHost(contents: [.number(1), .number(2), .number(3)])
}

// b04 · b06 — 지도에 찍힌 장소
#Preview("카테고리 아이콘") {
    MapPlacePinPreviewHost(
        contents: [
            .category(.categoryFood),
            .category(.categoryCafe),
            .category(.categoryShopping)
        ]
    )
}

// 흰 테두리와 그림자가 보이는지 어두운 바닥에서도 본다
#Preview("번호 · 아이콘 섞어") {
    VStack(spacing: 0) {
        MapPlacePinPreviewHost(contents: [.number(1), .category(.categoryTourism)])

        ZStack {
            Color.gray700

            HStack(spacing: Spacing.s24) {
                MapPlacePin(content: .number(1))
                MapPlacePin(content: .category(.categoryTourism))
            }
        }
        .frame(height: 160)
    }
}
