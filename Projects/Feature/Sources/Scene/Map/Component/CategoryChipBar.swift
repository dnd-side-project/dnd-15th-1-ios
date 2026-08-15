import SharedDesignSystem
import SwiftUI

// MARK: - CategoryChipMetric

private enum CategoryChipMetric {
    static let height: CGFloat = 36
    static let iconSize: CGFloat = 20
    static let borderWidth: CGFloat = 1
    static let shadowRadius: CGFloat = 4
    static let shadowOffsetY: CGFloat = 2
    static let shadowOpacity: Double = 0.12
    /// 지도 위에 떠 있어 그림자가 `ScrollView` 에 잘린다. 위아래로 그만큼 자리를 준다.
    static let shadowClearance = Spacing.s8
}

// MARK: - CategoryChipItem

/// 칩 하나가 갖는 값. `Domain` 타입을 받지 않는다.
///
/// `Equatable` 이라 리듀서 `State` 안에 그대로 담을 수 있다.
/// `SwiftUI.Image` 자체가 `Equatable` 이므로 합성 구현이 그대로 성립한다.
struct CategoryChipItem<ID: Hashable>: Identifiable, Equatable {
    public let id: ID
    public let icon: Image
    public let title: String

    public init(id: ID, icon: Image, title: String) {
        self.id = id
        self.icon = icon
        self.title = title
    }
}

// MARK: - CategoryChipBar

/// 지도 위에 떠 있는 카테고리 칩 가로 스크롤.
///
/// 배경은 고르든 안 고르든 흰색이다. 고르면 테두리와 글자만 진해진다.
/// 탐색 탭의 `FilterChip`(고르면 `gray900` 으로 꽉 참)과 모양이 달라 그 파일을 쓰지 않는다.
///
/// 선택값은 값으로만 받고 탭은 그대로 올린다. 탐색 탭의 `FilterChip` + `store.send(...)` 와 같은 결이다.
///
/// ```swift
/// CategoryChipBar(items: items, selection: store.selectedCategoryID) { id in
///     store.send(.categoryTapped(id))
/// }
/// ```
public struct CategoryChipBar<ID: Hashable>: View {
    private let items: [CategoryChipItem<ID>]
    private let selection: ID?
    private let onTap: (ID) -> Void

    init(items: [CategoryChipItem<ID>], selection: ID?, onTap: @escaping (ID) -> Void) {
        self.items = items
        self.selection = selection
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s4) {
                ForEach(items) { item in
                    // 같은 칩을 다시 눌렀을 때 해제할지는 화면마다 다를 수 있어 여기서 정하지 않는다.
                    // 누른 id 를 그대로 올리고 단일/다중·재탭 해제 규칙은 리듀서가 정한다.
                    CategoryChip(item: item, isSelected: item.id == selection) {
                        onTap(item.id)
                    }
                }
            }
            .padding(.horizontal, Spacing.s20)
            .padding(.vertical, CategoryChipMetric.shadowClearance)
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip<ID: Hashable>: View {
    let item: CategoryChipItem<ID>
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s4) {
                item.icon
                    .resizable()
                    .frame(
                        width: CategoryChipMetric.iconSize,
                        height: CategoryChipMetric.iconSize
                    )

                Text(item.title)
                    .typography(.body1M)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.s16)
            .frame(height: CategoryChipMetric.height)
            .background { background }
            .overlay { border }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: some View {
        Capsule()
            .fill(Color.bgDefault)
            .shadow(
                color: Color.commonBlack.opacity(CategoryChipMetric.shadowOpacity),
                radius: CategoryChipMetric.shadowRadius,
                y: CategoryChipMetric.shadowOffsetY
            )
    }

    private var border: some View {
        Capsule()
            .strokeBorder(
                isSelected ? Color.textPrimary : Color.borderDefault,
                lineWidth: CategoryChipMetric.borderWidth
            )
    }
}

// MARK: - Preview Fixture

private enum CategoryChipBarPreview {
    static var items: [CategoryChipItem<String>] {
        [
            CategoryChipItem(id: "food", icon: .categoryFood, title: "맛집"),
            CategoryChipItem(id: "cafe", icon: .categoryCafe, title: "카페"),
            CategoryChipItem(id: "activity", icon: .categoryActivity, title: "놀거리"),
            CategoryChipItem(id: "shopping", icon: .categoryShopping, title: "쇼핑")
        ]
    }
}

/// 지도 자리. 실제 지도는 이 부품이 그리지 않는다.
private struct CategoryChipBarPreviewMap: View {
    var body: some View {
        Color.gray300
            .ignoresSafeArea()
    }
}

// MARK: - Preview

// a01 · a08: 지도 위 칩 줄. 아직 아무것도 안 고른 기본 상태
// 재탭 해제는 부품이 아니라 부르는 쪽 규칙이라 프리뷰가 직접 구현한다
#Preview("선택 없음") {
    @Previewable @State var selection: String?

    ZStack(alignment: .top) {
        CategoryChipBarPreviewMap()

        CategoryChipBar(items: CategoryChipBarPreview.items, selection: selection) { id in
            selection = (selection == id) ? nil : id
        }
    }
}

// a01 · a08: 하나 고르면 배경은 흰색 그대로고 테두리·글자만 진해진다
#Preview("하나 선택") {
    @Previewable @State var selection: String? = "cafe"

    ZStack(alignment: .top) {
        CategoryChipBarPreviewMap()

        CategoryChipBar(items: CategoryChipBarPreview.items, selection: selection) { id in
            selection = (selection == id) ? nil : id
        }
    }
}
