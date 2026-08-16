import SharedDesignSystem
import SwiftUI

// tip 버튼 아래에 붙는 말풍선. 위쪽 화살표가 버튼 가운데를 가리키도록 트레일링 기준으로 놓는다
struct DateTypeTooltip: View {
    let text: String
    /// 말풍선 오른쪽 끝에서 화살표 중심까지의 거리. 무엇을 가리킬지는 배치하는 쪽이 정한다
    let arrowTrailingInset: CGFloat

    var body: some View {
        bubble
            .frame(width: BubbleMetric.width)
            .overlay(alignment: .topTrailing) { arrow }
            .compositingGroup()
            .shadow(color: .black.opacity(0.1), radius: BubbleMetric.shadowRadius, x: 0, y: BubbleMetric.shadowYOffset)
    }

    /// 솟은 부분은 레이아웃 높이에 안 들어간다. 그래서 뷰의 top 은 곧 말풍선의 top 이고,
    /// 화살표 끝은 뷰 top 보다 protrusion 만큼 위에 있다
    private var arrow: some View {
        ArrowShape()
            .fill(Color.commonWhite)
            .frame(width: ArrowMetric.width, height: ArrowMetric.height)
            .offset(
                x: -(arrowTrailingInset - ArrowMetric.width / 2),
                y: -ArrowMetric.protrusion
            )
    }

    private var bubble: some View {
        Text(text)
            .typography(.caption2M)
            .foregroundStyle(Color.textPrimary)
            // overlay 로 얹히면 tip 버튼 높이가 그대로 제안돼 한 줄로 잘린다. 이상적 높이를 쓰게 고정한다
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BubbleMetric.horizontalPadding)
            .padding(.vertical, BubbleMetric.verticalPadding)
            .background(Color.commonWhite)
            .clipShape(RoundedRectangle(cornerRadius: BubbleMetric.cornerRadius))
    }

    private struct ArrowShape: Shape {
        /// 시안 SVG(17.86x16, 모서리 radius 2 라운드 삼각형) 좌표를 그대로 쓰고 rect 크기에 맞춰 스케일한다
        func path(in rect: CGRect) -> Path {
            let scaleX = rect.width / ArrowMetric.width
            let scaleY = rect.height / ArrowMetric.height
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
            }

            var path = Path()
            path.move(to: point(7.19914, 1))
            path.addCurve(
                to: point(10.6632, 1),
                control1: point(7.96894, -0.333333),
                control2: point(9.89344, -0.333333)
            )
            path.addLine(to: point(17.5914, 13))
            path.addCurve(
                to: point(15.8594, 16),
                control1: point(18.3612, 14.3333),
                control2: point(17.399, 16)
            )
            path.addLine(to: point(2.00298, 16))
            path.addCurve(
                to: point(0.270933, 13),
                control1: point(0.463383, 16),
                control2: point(-0.498867, 14.3333)
            )
            path.closeSubpath()
            return path
        }
    }
}

extension DateTypeTooltip {
    struct Placement {
        let trailingOffset: CGFloat
        let topOffset: CGFloat
        let arrowTrailingInset: CGFloat
    }

    static func placement(
        tipButtonTrailingX: CGFloat,
        tipButtonCenterX: CGFloat,
        tipButtonHeight: CGFloat
    ) -> Placement {
        Placement(
            // 말풍선은 tip 버튼 오른쪽 끝에 트레일링 정렬된다. 시안 위치까지 그만큼 오른쪽으로 민다
            trailingOffset: PlacementMetric.leadingInset + BubbleMetric.width - tipButtonTrailingX,
            // overlay 의 y 원점은 tip 버튼 상단이고, 화살표 끝은 말풍선 상단보다 ArrowMetric.protrusion 만큼 위다
            topOffset: tipButtonHeight + PlacementMetric.arrowGap + ArrowMetric.protrusion,
            // 말풍선 왼쪽 끝이 42 로 고정이므로, 화살표가 tip 버튼 가운데를 가리키는 위치도 여기서 정해진다
            arrowTrailingInset: PlacementMetric.leadingInset + BubbleMetric.width - tipButtonCenterX
        )
    }
}

private enum BubbleMetric {
    static let width: CGFloat = 262
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 4
    static let shadowYOffset: CGFloat = 2
}

private enum ArrowMetric {
    static let width: CGFloat = 17.86
    static let height: CGFloat = 16
    /// 밑변 6 은 말풍선 안에 묻는다. 이음새와 내부 그림자가 안 생긴다
    static let overlap: CGFloat = 6
    /// 화살표 뾰족한 끝이 말풍선 위로 솟은 높이
    static let protrusion: CGFloat = height - overlap
}

private enum PlacementMetric {
    /// 시안: 말풍선 왼쪽 끝이 화면 왼쪽에서 42
    static let leadingInset: CGFloat = 42
    /// 시안: 화살표 뾰족한 끝이 tip 버튼 하단에서 4 아래
    static let arrowGap: CGFloat = 4
}

#if DEBUG
#Preview("툴팁") {
    let placement = DateTypeTooltip.placement(
        tipButtonTrailingX: 293,
        tipButtonCenterX: 273,
        tipButtonHeight: 32
    )
    DateTypeTooltip(
        text: DateTypeView.tooltipText,
        arrowTrailingInset: placement.arrowTrailingInset
    )
    .padding(40)
    .background(Color.primaryPink)
}
#endif
