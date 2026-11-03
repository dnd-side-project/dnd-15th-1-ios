import CoreUserAnalytics
import SharedDesignSystem
import SwiftUI

// MARK: - SavedPlaceSearchField

/// 「검색」 칩이 줄 너비로 늘어나 된 검색창.
///
/// 칩과 같은 높이 · 같은 알약 모양이라, 칩에서 늘어나는 전환이 이어지고 시트 머리 높이가 그대로다.
/// 포커스는 부르는 쪽이 들고 있다. 행을 누르거나 지도를 누르면 부르는 쪽이 내린다
struct SavedPlaceSearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: SavedPlaceSearchChipMetric.iconTextSpacing) {
            TextField(
                "",
                text: $text,
                prompt: Text("찾고싶은 장소를 검색하세요")
                    .font(Typography.body1M.font)
                    .foregroundStyle(Color.gray400)
            )
            .typography(.body1M)
            .foregroundStyle(Color.gray900)
            .submitLabel(.search)
            .focused(isFocused)
            .onSubmit(onSubmit)
            .analyticsMasked()

            // 시안 `5054:29310` · `5054:31210`: 돋보기는 입력칸 뒤에 회색으로 둔다
            Image.search
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: SavedPlaceSearchChipMetric.searchIconSize,
                    height: SavedPlaceSearchChipMetric.searchIconSize
                )
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, SavedPlaceSearchChipMetric.horizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: SavedPlaceSearchChipMetric.height)
        .background(Color.bgSubtle)
        // 시안 검색창은 테두리가 없다. 칩의 선택 테두리와 다르다
        .clipShape(Capsule())
        // 입력칸 밖 여백 · 돋보기를 눌러도 포커스가 잡히게 한다
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
    }
}
