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
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

enum BubbleMetric {
    static let width: CGFloat = 262
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 4
    static let shadowYOffset: CGFloat = 2
}

enum ArrowMetric {
    static let width: CGFloat = 17.86
    static let height: CGFloat = 16
    /// 밑변 6 은 말풍선 안에 묻는다. 이음새와 내부 그림자가 안 생긴다
    static let overlap: CGFloat = 6
    /// 화살표 뾰족한 끝이 말풍선 위로 솟은 높이
    static let protrusion: CGFloat = height - overlap
}

#if DEBUG
#Preview("툴팁") {
    DateTypeTooltip(
        text: DateTypeView.tooltipText,
        arrowTrailingInset: TooltipMetric.arrowTrailingInset
    )
    .padding(40)
    .background(Color.primaryPink)
}
#endif
