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

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text(store.sectionTitle)
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)

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

            if store.isLoadingContents {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }
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
