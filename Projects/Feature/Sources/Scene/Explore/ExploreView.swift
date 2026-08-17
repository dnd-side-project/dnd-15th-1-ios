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
            Text("지금 인기있는 장소")
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)

            LazyVGrid(columns: columns, spacing: Spacing.s32) {
                ForEach(store.posts) { post in
                    PostCard(post: post)
                }
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
