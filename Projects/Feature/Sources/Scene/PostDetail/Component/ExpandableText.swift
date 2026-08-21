//
//  ExpandableText.swift
//  Dulpick
//

import SharedDesignSystem
import SwiftUI

/// 본문을 세 줄로 자르고, 넘칠 때만 `더보기` 를 붙인다.
///
/// 자른 높이와 전문 높이를 견줘 넘침을 판정한다.
/// 보이는 글에 `lineLimit` 을 걸어 재면 펼친 뒤에 넘침을 알 수 없다
struct ExpandableText: View {
    let text: String
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var fullHeight: CGFloat = 0
    @State private var clampedHeight: CGFloat = 0

    private var isTruncated: Bool {
        fullHeight > clampedHeight + PostDetailMetric.truncationTolerance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text(text)
                .typography(.body2M)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(isExpanded ? nil : PostDetailMetric.captionLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .top) { measuringLayers }

            if isTruncated {
                Button(action: onToggle) {
                    Text(isExpanded ? "접기" : "더보기")
                        .typography(.body2SB)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.vertical, Spacing.s4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 같은 폭으로 깔려 높이만 재는 두 겹. 그리지 않고 손도 안 받는다
    private var measuringLayers: some View {
        ZStack(alignment: .top) {
            Text(text)
                .typography(.body2M)
                .lineLimit(nil)
                // `.background` 가 앞 겹(3줄) 높이를 제안하므로, 전문 겹은 그 제안을 무시한다
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }

            Text(text)
                .typography(.body2M)
                .lineLimit(PostDetailMetric.captionLineLimit)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { clampedHeight = $0 }
        }
        .hidden()
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("세 줄을 넘김") {
    ExpandableText(text: PostDetailContent.fixture().caption ?? "", isExpanded: false) {}
        .padding(Spacing.s20)
}

#Preview("펼침") {
    ExpandableText(text: PostDetailContent.fixture().caption ?? "", isExpanded: true) {}
        .padding(Spacing.s20)
}

#Preview("짧은 글") {
    ExpandableText(text: "한 줄짜리 본문", isExpanded: false) {}
        .padding(Spacing.s20)
}
#endif
