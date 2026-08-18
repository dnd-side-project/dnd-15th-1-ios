import SharedDesignSystem
import SwiftUI

// MARK: - MapSearchBarMetric

private enum MapSearchBarMetric {
    static let height: CGFloat = 48
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1
    static let buttonSize: CGFloat = 48
    static let buttonCornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 24
}

// MARK: - MapSearchBar

/// 지도 위 검색바. 글자를 받지 않고 탭만 올린다.
///
/// 실제 검색 화면은 Cycle 3 이다. 여기서는 자리와 모양만 맞춘다.
struct MapSearchBar: View {
    private let placeholder: String
    private let action: () -> Void

    init(placeholder: String, action: @escaping () -> Void) {
        self.placeholder = placeholder
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s4) {
                Text(placeholder)
                    .typography(.body1M)
                    .foregroundStyle(Color.gray400)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.s20)
                    .frame(height: MapSearchBarMetric.height)
                    .background(Color.bgDefault)
                    .clipShape(RoundedRectangle(cornerRadius: MapSearchBarMetric.cornerRadius))
                    .overlay {
                        // 선이 안쪽에 그려져야 높이가 48 로 유지된다
                        RoundedRectangle(cornerRadius: MapSearchBarMetric.cornerRadius)
                            .strokeBorder(Color.borderDefault, lineWidth: MapSearchBarMetric.borderWidth)
                    }

                Image.search
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: MapSearchBarMetric.iconSize,
                        height: MapSearchBarMetric.iconSize
                    )
                    .foregroundStyle(Color.textInverseTertiary)
                    .frame(
                        width: MapSearchBarMetric.buttonSize,
                        height: MapSearchBarMetric.buttonSize
                    )
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: MapSearchBarMetric.buttonCornerRadius))
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
// a08 — 지도 위 검색바
#Preview {
    ZStack(alignment: .top) {
        Color.gray300.ignoresSafeArea()
        MapSearchBar(placeholder: "원하는 장소를 검색하세요") {}
            .padding(.horizontal, Spacing.s20)
    }
}
#endif
