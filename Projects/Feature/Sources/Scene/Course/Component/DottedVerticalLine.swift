import SharedDesignSystem
import SwiftUI

// MARK: - DottedVerticalLine

/// 세로로 내려가는 점선 한 줄.
///
/// `CourseTimeline` 의 레일과 `ReorderableList` 의 카드 사이 점선이 같은 그림이라 한곳에 둔다.
/// 색과 길이만 부르는 쪽이 정한다. 굵기·점 주기·동그란 점 모양은 여기서 고정한다.
///
/// 길이는 붙이는 쪽에서 준다.
///
/// ```swift
/// DottedVerticalLine(color: .brandPrimary)
///     .frame(maxHeight: .infinity)
/// ```
struct DottedVerticalLine: View {

    // View 라 타입이 메인 액터에 묶인다. 이 규격은 값일 뿐이고 배치를 맞추는 쪽에서
    // 액터 밖 상수 계산에 쓰이므로 nonisolated 로 연다.

    /// 획 굵기이자 점 지름. 점선 중심을 다른 좌표에 맞추는 쪽이 읽는다.
    nonisolated static let lineWidth: CGFloat = 2
    /// 점 하나에서 다음 점까지. 여백을 이 주기로 나눠 길이를 잡는 쪽이 읽는다.
    nonisolated static let dotSpacing: CGFloat = 5

    // 길이 0 인 dash 를 round 캡으로 찍어 동그란 점을 만든다
    nonisolated private static let dash: [CGFloat] = [0.01, dotSpacing]

    private let color: Color

    init(color: Color) {
        self.color = color
    }

    var body: some View {
        DottedVerticalLineShape()
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: Self.lineWidth,
                    lineCap: .round,
                    dash: Self.dash
                )
            )
            .frame(width: Self.lineWidth)
    }
}

// MARK: - DottedVerticalLineShape

private struct DottedVerticalLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Preview

#if DEBUG
// 왼쪽은 타임라인 레일, 오른쪽은 카드 사이 짧은 구간
#Preview("점선") {
    HStack(spacing: Spacing.s32) {
        DottedVerticalLine(color: .brandPrimary)
            .frame(height: 120)

        DottedVerticalLine(color: .borderDefault)
            .frame(height: 20)
    }
    .padding(Spacing.s24)
}
#endif
