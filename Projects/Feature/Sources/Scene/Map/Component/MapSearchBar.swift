import SharedDesignSystem
import SwiftUI

// MARK: - MapSearchBarMetric

private enum MapSearchBarMetric {
    static let height: CGFloat = 48
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1
    /// 오른쪽 돋보기. 뒤로가기 원(44)과 크기가 다르다
    static let buttonSize: CGFloat = 48
    static let buttonCornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 24
}

// MARK: - MapSearchBar

/// 지도 위 검색바.
///
/// 저장 장소 모드에서는 글자를 안 받고 탭만 올린다.
/// 검색 모드에서는 검색어를 보여주고 우측에 지우기를 준다.
struct MapSearchBar: View {
    private let placeholder: String
    private let text: String?
    private let onTap: () -> Void
    private let onClear: (() -> Void)?
    private let onBack: (() -> Void)?

    init(
        placeholder: String,
        text: String? = nil,
        onTap: @escaping () -> Void,
        onClear: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self.text = text
        self.onTap = onTap
        self.onClear = onClear
        self.onBack = onBack
    }

    var body: some View {
        if onBack != nil {
            // 기본 네비바 뒤로가기와 같은 높이에 서게 입력칸 가운데가 아니라 위에 붙인다
            HStack(alignment: .top, spacing: Spacing.s12) {
                BackButton { onBack?() }
                field
            }
            .padding(.leading, BackButtonMetric.leadingInset)
            .padding(.trailing, Spacing.s20)
        } else {
            HStack(spacing: Spacing.s4) {
                field
                searchButton
            }
            .padding(.horizontal, Spacing.s20)
        }
    }

    private var field: some View {
        HStack(spacing: Spacing.s8) {
            // 지우기 버튼과 손짓이 겹치지 않게 글자 칸만 탭을 받는다
            Text(text ?? placeholder)
                .typography(.body1M)
                .foregroundStyle(text == nil ? Color.gray400 : Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, Spacing.s20)
                .padding(.trailing, text != nil && onClear != nil ? 0 : Spacing.s20)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            if text != nil, let onClear {
                Button(action: onClear) {
                    Image.x
                        .renderingMode(.template)
                        .resizable()
                        .frame(
                            width: MapSearchBarMetric.iconSize,
                            height: MapSearchBarMetric.iconSize
                        )
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Spacing.s20)
            }
        }
        .frame(height: MapSearchBarMetric.height)
        .background(Color.bgDefault)
        .clipShape(RoundedRectangle(cornerRadius: MapSearchBarMetric.cornerRadius))
        .overlay {
            // 선이 안쪽에 그려져야 높이가 48 로 유지된다
            RoundedRectangle(cornerRadius: MapSearchBarMetric.cornerRadius)
                .strokeBorder(Color.borderDefault, lineWidth: MapSearchBarMetric.borderWidth)
        }
    }

    private var searchButton: some View {
        Button(action: onTap) {
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
        .buttonStyle(.plain)
    }
}

#if DEBUG
// a08 — 지도 위 검색바
#Preview("저장 장소") {
    ZStack(alignment: .top) {
        Color.gray300.ignoresSafeArea()
        MapSearchBar(placeholder: "원하는 장소를 검색하세요", onTap: {})
    }
}

#Preview("검색") {
    ZStack(alignment: .top) {
        Color.gray300.ignoresSafeArea()
        MapSearchBar(
            placeholder: "원하는 장소를 검색하세요",
            text: "음식점",
            onTap: {},
            onClear: {},
            onBack: {}
        )
    }
}
#endif
