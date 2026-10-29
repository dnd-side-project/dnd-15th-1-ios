import CoreUserAnalytics
import SharedDesignSystem
import SwiftUI

// MARK: - SavedPlaceSearchChipMetric

/// 시안 `5041:43989`. 값은 시안 대조에서 확정한다
enum SavedPlaceSearchChipMetric {
    /// 칩과 검색창이 같은 높이라 바뀌어도 시트 머리 높이가 그대로다
    static let height: CGFloat = 36
    static let horizontalPadding: CGFloat = Spacing.s16
    static let iconTextSpacing: CGFloat = Spacing.s4
    static let searchIconSize: CGFloat = 20
    static let clearIconSize: CGFloat = 16
    static let borderWidth: CGFloat = 1
    /// 목록을 불러오는 중 · 실패 때 흐리게
    static let disabledOpacity: CGFloat = 0.4
}

// MARK: - SavedPlaceSearchChip

/// 「저장한 장소」 시트 필터 줄 맨 앞 칩.
///
/// 검색어가 없으면 [🔍 검색], 있으면 선택 상태의 [🔍 검색어 ✕] 다.
/// 검색어는 줄에 남은 너비까지만 늘고 넘치면 「…」 로 자른다. ✕ 는 잘리지 않는다
struct SavedPlaceSearchChip: View {
    let query: String
    let onTap: () -> Void
    let onClear: () -> Void

    private var isSelected: Bool { !query.isEmpty }

    var body: some View {
        HStack(spacing: SavedPlaceSearchChipMetric.iconTextSpacing) {
            Button(action: onTap) {
                HStack(spacing: SavedPlaceSearchChipMetric.iconTextSpacing) {
                    Image.search
                        .renderingMode(.template)
                        .resizable()
                        .frame(
                            width: SavedPlaceSearchChipMetric.searchIconSize,
                            height: SavedPlaceSearchChipMetric.searchIconSize
                        )

                    Text(isSelected ? query : "검색")
                        .typography(.body1M)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .analyticsMasked(isSelected)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected {
                clearButton
            }
        }
        .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
        .padding(.horizontal, SavedPlaceSearchChipMetric.horizontalPadding)
        .frame(height: SavedPlaceSearchChipMetric.height)
        .background(isSelected ? Color.bgSubtle : Color.bgDefault)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected ? Color.textPrimary : Color.borderDefault,
                    lineWidth: SavedPlaceSearchChipMetric.borderWidth
                )
        }
    }

    private var clearButton: some View {
        Button(action: onClear) {
            Image.x
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: SavedPlaceSearchChipMetric.clearIconSize,
                    height: SavedPlaceSearchChipMetric.clearIconSize
                )
                .accessibilityLabel("검색어 지우기")
        }
        .buttonStyle(.plain)
        // 검색어가 길어도 ✕ 는 줄지 않는다
        .layoutPriority(1)
    }
}
