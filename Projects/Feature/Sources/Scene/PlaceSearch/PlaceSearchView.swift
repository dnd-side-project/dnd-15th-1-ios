import CoreUserAnalytics
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
    /// 저장한 곳만 보기 줄 아래 띠
    static let savedOnlyDividerHeight: CGFloat = 4
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
            // 커플이 없으면 서버가 404 를 준다. 지도 탭 저장자 필터처럼 줄째 감춘다
            if store.isCoupleConnected {
                savedOnlyToggleRow
            }
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
            .analyticsMasked()
        }
        .padding(.leading, BackButtonMetric.leadingInset)
        .padding(.trailing, Spacing.s20)
        .padding(.bottom, PlaceSearchMetric.topBarBottomInset)
    }

    /// 검색창 아래 오른쪽. 아래 띠가 목록과 가른다
    private var savedOnlyToggleRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                Toggle(isOn: $store.isSavedOnly) {
                    Text("저장한 곳만 보기")
                        .typography(.body2M)
                        .foregroundStyle(Color.textPrimary)
                }
                .toggleStyle(AppToggleStyle())
            }
            .padding(.horizontal, Spacing.s20)
            .padding(.vertical, Spacing.s8)

            Rectangle()
                .fill(Color.borderWeak)
                .frame(height: PlaceSearchMetric.savedOnlyDividerHeight)
        }
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
            if store.isAwaitingResults {
                skeleton
            } else if store.results.isEmpty {
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
                .analyticsMasked()

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

    /// 검색 화면의 행은 사진과 우측 슬롯을 안 쓴다.
    /// 커플이 저장한 곳은 빨간 북마크, 아닌 곳은 회색 핀이다. 별칭이 있으면 이름 대신 별칭을 보이고 녹화에서 가린다
    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.results.enumerated()), id: \.element.id) { index, result in
                    PlaceListRow(
                        icon: result.ownership == nil ? Image.mapPin : Image.bookmarkFilled,
                        name: result.alias ?? result.place.name,
                        address: result.place.address,
                        isNameSensitive: result.alias != nil,
                        iconTint: result.ownership == nil ? Color.gray200 : nil,
                        category: result.place.category.displayName
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.rowTapped(result.id)) }
                    .onAppear {
                        if index == max(0, store.results.count - 3) {
                            store.send(.reachedEnd)
                        }
                    }
                }
                // 걸러져 짧아진 페이지는 위 기준 행이 이미 보인 행이라 다시 안 불린다.
                // 페이지마다 새로 나타나는 끝 표시로 받친다
                if store.hasNext {
                    Color.clear
                        .frame(height: 1)
                        .id(store.page)
                        .onAppear { store.send(.reachedEnd) }
                }
            }
        }
        // 토글 줄이 있으면 그 아래 띠에 바로 붙는다
        .padding(.top, store.isCoupleConnected ? 0 : Spacing.s8)
    }

    private var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< PlaceSearchMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: PlaceSearchMetric.cornerRadius)
                    .frame(height: PlaceSearchMetric.skeletonRowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        // 결과 목록과 같은 자리에 서야 로딩이 끝날 때 내용이 튀지 않는다
        .padding(.top, store.isCoupleConnected ? 0 : Spacing.s8)
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
