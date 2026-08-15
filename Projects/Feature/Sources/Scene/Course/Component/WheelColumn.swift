// 날짜·시간 피커가 나눠 쓰는 휠 뼈대.

import SharedDesignSystem
import SwiftUI

// MARK: - WheelMetrics

/// 휠 피커 두 개(`DateWheelPicker` · `TimeWheelPicker`)가 나눠 쓰는 치수.
enum WheelMetrics {
    /// 264 = 위아래 여백 32 + 열 높이 200 + 32
    static let areaHeight: CGFloat = 264
    static let columnHeight: CGFloat = 200
    static let columnWidth: CGFloat = 48
    static let columnSpacing: CGFloat = 72
    static let rowHeight: CGFloat = 24
    /// 행 사이 20 → 한 칸 44. 24×5 + 20×4 = 200 이라 다섯 행이 딱 보인다.
    static let rowSpacing: CGFloat = 20

    /// 첫·마지막 항목도 가운데로 올 수 있게 열 위아래에 두는 빈자리. (200 − 24) ÷ 2 = 88 = 두 칸.
    ///
    /// `scrollContent` 여백으로 주면 실제 스냅 영역이 24pt(가운데 한 행)로 좁아져
    /// `.viewAligned` 가 항목을 열 한가운데에 맞춘다.
    static let columnContentInset: CGFloat = (columnHeight - rowHeight) / 2

    static let selectionBarHeight: CGFloat = 48
    static let selectionBarCornerRadius: CGFloat = Spacing.s8
    static let selectionBarHorizontalInset: CGFloat = Spacing.s20
}

// MARK: - WheelFormat

/// 휠 피커 두 개가 나눠 쓰는 항목 표기.
enum WheelFormat {
    /// 한 자리 수도 앞에 0 을 붙여 두 자리로 맞춘다. 열 폭이 고정이라 자릿수가 흔들리면 안 된다.
    static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

// MARK: - WheelSelectionBar

/// 세 열을 가로지르는 선택 바. 열 뒤층에 깔리고 가운데 행에 세로 중심을 맞춘다.
struct WheelSelectionBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: WheelMetrics.selectionBarCornerRadius, style: .continuous)
            .fill(Color.bgSubtle)
            .frame(maxWidth: .infinity)
            .frame(height: WheelMetrics.selectionBarHeight)
            .padding(.horizontal, WheelMetrics.selectionBarHorizontalInset)
    }
}

// MARK: - WheelColumn

/// 휠 한 열. 평평한 스크롤 목록이라 3D 로 말리지 않는다.
struct WheelColumn<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item?
    let title: (Item) -> String

    /// 스크롤 위치는 따로 들고 간다. 처음부터 값이 들어 있으면 첫 스크롤이 걸리지 않아
    /// `nil` 로 시작했다가 `onAppear` 에서 채워 넣어야 선택값 자리로 움직인다.
    @State private var position: Item?

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: WheelMetrics.rowSpacing) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selection

                    Text(title(item))
                        .typography(isSelected ? .body1SB : .body1M)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                        .lineLimit(1)
                        .frame(width: WheelMetrics.columnWidth, height: WheelMetrics.rowHeight)
                }
            }
            .scrollTargetLayout()
        }
        .frame(width: WheelMetrics.columnWidth, height: WheelMetrics.columnHeight)
        .scrollPosition(id: $position, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.vertical, WheelMetrics.columnContentInset, for: .scrollContent)
        .scrollIndicators(.hidden)
        .onAppear { position = selection }
        .onChange(of: position) { _, newValue in
            guard let newValue, newValue != selection else { return }
            selection = newValue
        }
        .onChange(of: selection) { _, newValue in
            // 밖에서 값이 바뀐 경우(달이 바뀌어 일이 내려간 경우 등) 그 자리로 다시 맞춘다.
            guard let newValue, newValue != position else { return }
            position = newValue
        }
    }
}
