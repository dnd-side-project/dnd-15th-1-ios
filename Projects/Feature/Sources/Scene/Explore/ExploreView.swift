//
//  ExploreView.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct ExploreView: View {
    @Bindable public var store: StoreOf<ExploreFeature>

    // 화면당 하나. 카드가 보일 때 썸네일 미리 받아 스크롤 매끄럽게
    @State private var prefetcher = RemoteImagePrefetcher()

    public init(store: StoreOf<ExploreFeature>) {
        self.store = store
    }

    private let columns = [
        GridItem(.flexible(), spacing: 11, alignment: .top),
        GridItem(.flexible(), spacing: 11, alignment: .top),
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                filterChips
                popularSection
            }
            .padding(.horizontal, Spacing.s20)
            .padding(.top, 6)
        }
        .navigationDestination(for: ExploreFeature.Route.self) { route in
            searchDestination(route)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("탐색")
                    .typography(.title2B)
                    .foregroundStyle(Color.gray900)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.searchButtonTapped)
                } label: {
                    Image.search
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .toolbarRole(.editor)
        .task { store.send(.onAppear) }
    }

    // 끝에서 세 번째 카드가 보이면 미리 다음 페이지 로드해 스크롤 안 끊기게
    private func prefetchIfNeeded(_ content: Content) {
        if content.id == store.contents.suffix(3).first?.id {
            store.send(.reachedEnd)
        }
    }

    @ViewBuilder
    private func searchDestination(_ route: ExploreFeature.Route) -> some View {
        if let searchStore = store.scope(state: \.search, action: \.search) {
            switch route {
            case .search:
                SearchView(store: searchStore)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if store.isInitialLoading {
                    // 로딩 중엔 인기 칩도 선명하면 어색해 칩 자리를 스켈레톤 4개로만 채운다
                    ForEach(0 ..< ExploreViewMetric.skeletonChipCount, id: \.self) { _ in
                        skeletonChip
                    }
                } else {
                    ForEach(store.filters, id: \.self) { filter in
                        FilterChip(
                            title: filter,
                            isSelected: store.selectedFilter == filter
                        ) {
                            store.send(.filterTapped(filter))
                        }
                    }
                }
            }
        }
    }

    // 실제 FilterChip 과 같은 글자·패딩으로 자리를 잡고 그 위를 시머로 덮는다
    private var skeletonChip: some View {
        Text(ExploreViewMetric.skeletonChipPlaceholder)
            .typography(.body1M)
            .foregroundStyle(Color.clear)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background {
                ShimmerBlock(cornerRadius: 12, baseColor: .bgSubtle)
            }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text(store.sectionTitle)
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)

            if store.isInitialLoading {
                skeletonGrid
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.s32) {
                    ForEach(store.contents) { content in
                        Button {
                            store.send(.contentTapped(content.id))
                        } label: {
                            ContentCard(content: content)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            prefetchIfNeeded(content)
                            prefetcher.start(content.thumbnailURLs)
                        }
                        .onDisappear { prefetcher.stop(content.thumbnailURLs) }
                    }
                }

                // 다음 페이지를 이어 받을 때만. 최초 로딩은 위 스켈레톤이 대신한다
                if store.isLoadingContents {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
    }

    // 실제 그리드와 같은 열·간격으로 2×2 카드 골격을 깐다
    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s32) {
            ForEach(0 ..< ExploreViewMetric.skeletonCardCount, id: \.self) { _ in
                skeletonCard
            }
        }
    }

    // ContentCard 와 같은 비율·모서리·간격으로 이미지와 2줄 제목 자리를 시머로 채운다
    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Color.clear
                .aspectRatio(170.0 / 227.0, contentMode: .fit)
                .overlay {
                    ShimmerBlock(baseColor: .gray300)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // 제목 2줄 자리. 둘째 줄은 짧게 둬 실제 텍스트처럼 보이게 한다
            VStack(alignment: .leading, spacing: 6) {
                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(height: 14)
                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(width: 60, height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private enum ExploreViewMetric {
    static let skeletonChipPlaceholder = "#태그"
    static let skeletonChipCount = 4
    static let skeletonCardCount = 4
}

#Preview {
    NavigationStack {
        ExploreView(
            store: Store(initialState: ExploreFeature.State()) {
                ExploreFeature()
            } withDependencies: {
                $0.exploreClient = .mock
            }
        )
    }
}
