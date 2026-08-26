import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

// MARK: - PlaceSearchMetric

private enum PlaceSearchMetric {
    /// 최근 검색어 행 왼쪽 돋보기의 배경 원
    static let recentSearchIconBackgroundSize: CGFloat = 28
    /// 그 안의 돋보기
    static let recentSearchIconSize: CGFloat = 16
    /// 최근 검색어 행 오른쪽 지우기
    static let recentDeleteIconSize: CGFloat = 20
    static let cornerRadius: CGFloat = 12
    static let skeletonRowHeight: CGFloat = 64
    static let skeletonRowCount = 3
    /// 상단줄 아래 여백
    static let topBarBottomInset: CGFloat = 10
    /// 최근 검색어 제목 줄 위아래 여백
    static let recentHeaderVerticalInset: CGFloat = 17
    /// 빈 화면 그림
    static let emptyStateIconSize: CGFloat = 40
    /// 상단 줄과 빈 화면 틀 사이
    static let emptyStateGap: CGFloat = 40
    /// 빈 화면 틀 위아래 여백
    static let emptyStateVerticalInset: CGFloat = 40
}

// MARK: - PlaceSearchView

public struct PlaceSearchView: View {
    @Bindable public var store: StoreOf<PlaceSearchFeature>
    @State private var isSearchFieldFocused = false

    public init(store: StoreOf<PlaceSearchFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgDefault)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        // push 애니메이션 중에 준 포커스는 버려진다. 전환이 끝난 뒤에 준다
        .task {
            store.send(.onAppear)
            try? await Task.sleep(for: .milliseconds(400))
            isSearchFieldFocused = true
        }
        .onDisappear {
            isSearchFieldFocused = false
        }
    }

    private var topBar: some View {
        // 기본 네비바 뒤로가기와 같은 높이에 서게 입력칸 가운데가 아니라 위에 붙인다
        HStack(alignment: .top, spacing: Spacing.s12) {
            BackButton { store.send(.backTapped) }

            AppTextField(
                text: $store.query,
                placeholder: "원하는 장소를 검색하세요",
                size: .medium,
                style: .outlined,
                accessory: store.query.isEmpty ? .search : .clear,
                submitLabel: .search,
                isFocused: $isSearchFieldFocused,
                onSubmit: { store.send(.submitted) }
            )
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.bottom, PlaceSearchMetric.topBarBottomInset)
    }

    @ViewBuilder
    private var content: some View {
        if store.showsRecent {
            if store.recentSearches.isEmpty {
                emptyState(
                    title: "최근 검색한 기록이 없어요",
                    message: "데이트 장소를 검색해보세요"
                )
            } else {
                recentList
            }
        } else {
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch store.loadState {
        case .idle, .loading:
            skeleton
        case .failed:
            emptyState(
                title: "검색에 실패했어요",
                message: "잠시 뒤 다시 시도해주세요"
            )
        case .loaded:
            if store.results.isEmpty {
                emptyState(
                    title: "검색 결과가 없어요",
                    message: "다른 검색어를 입력해주세요"
                )
            } else {
                resultList
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        EmptyStateView(
            image: .cancel,
            imageSize: PlaceSearchMetric.emptyStateIconSize,
            imageColor: Color.borderDefault,
            title: title,
            message: message,
            alignment: .top
        )
        .padding(.vertical, PlaceSearchMetric.emptyStateVerticalInset)
        .padding(.top, PlaceSearchMetric.emptyStateGap)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("최근 검색어")
                    .typography(.title3SB)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    store.send(.clearRecentTapped)
                } label: {
                    Text("모두 지우기")
                        .typography(.body1SB)
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.s20)
            .padding(.vertical, PlaceSearchMetric.recentHeaderVerticalInset)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.recentSearches, id: \.self) { term in
                        recentRow(term)
                    }
                }
            }
        }
        .padding(.top, Spacing.s8)
    }

    private var recentSearchIcon: some View {
        Image.search
            .renderingMode(.template)
            .resizable()
            .frame(
                width: PlaceSearchMetric.recentSearchIconSize,
                height: PlaceSearchMetric.recentSearchIconSize
            )
            .foregroundStyle(Color.textTertiary)
            .frame(
                width: PlaceSearchMetric.recentSearchIconBackgroundSize,
                height: PlaceSearchMetric.recentSearchIconBackgroundSize
            )
            .background(Color.gray50)
            .clipShape(Circle())
    }

    private func recentRow(_ term: String) -> some View {
        HStack(spacing: Spacing.s12) {
            recentSearchIcon

            Text(term)
                .typography(.body1M)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Spacing.s8)

            Button {
                store.send(.recentSearchDeleted(term))
            } label: {
                Image.x
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: PlaceSearchMetric.recentDeleteIconSize,
                        height: PlaceSearchMetric.recentDeleteIconSize
                    )
                    .foregroundStyle(Color.gray300)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.vertical, Spacing.s12)
        .contentShape(Rectangle())
        .onTapGesture { store.send(.recentSearchTapped(term)) }
    }

    /// 검색 화면의 행은 사진과 우측 슬롯을 안 쓴다
    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.results.enumerated()), id: \.element.id) { index, place in
                    PlaceListRow(
                        icon: place.category.icon,
                        name: place.name,
                        address: place.address,
                        showsDivider: place.id != store.results.last?.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.rowTapped(place.id)) }
                    .onAppear {
                        if index == max(0, store.results.count - 3) {
                            store.send(.reachedEnd)
                        }
                    }
                }
            }
        }
        .padding(.top, Spacing.s8)
    }

    private var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< PlaceSearchMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: PlaceSearchMetric.cornerRadius)
                    .frame(height: PlaceSearchMetric.skeletonRowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s8)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#if DEBUG
// a15 — 최근 검색 기록이 없는 상태
#Preview {
    PlaceSearchView(
        store: Store(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        }
    )
}
#endif
