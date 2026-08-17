//
//  SearchView.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct SearchView: View {
    @Bindable public var store: StoreOf<SearchFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<SearchFeature>) {
        self.store = store
    }

    private let columns = [
        GridItem(.flexible(), spacing: 11, alignment: .top),
        GridItem(.flexible(), spacing: 11, alignment: .top),
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            if store.query.isEmpty {
                if !store.recentSearches.isEmpty {
                    recentSection
                        .padding(.top, Spacing.s20)
                }
                Spacer()
            } else {
                resultContent
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s20)
        .task { store.send(.onAppear) }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image.arrowLeft
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("검색")
                    .typography(.body1SB)
                    .foregroundStyle(Color.gray900)
            }
        }
    }

    private var searchField: some View {
        AppTextField(
            text: $store.query,
            placeholder: "원하는 장소를 검색해보세요",
            accessory: .search,
            submitLabel: .search,
            onSubmit: { store.send(.searchSubmitted) }
        )
        .padding(.bottom, 20)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
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
            }

            VStack(alignment: .leading, spacing: Spacing.s8) {
                ForEach(Array(recentRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Spacing.s8) {
                        ForEach(row, id: \.self) { term in
                            recentChip(term)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // 3개씩 묶어 2줄로 표시
    private var recentRows: [[String]] {
        stride(from: 0, to: store.recentSearches.count, by: 3).map { start in
            Array(store.recentSearches[start..<min(start + 3, store.recentSearches.count)])
        }
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s24) {
            segmentTabs

            if store.hasResult {
                resultList
            } else if !store.isSearching {
                EmptyStateView(
                    image: .placeEmpty,
                    title: "검색 결과가 없어요",
                    message: "다른 검색어를 입력해주세요"
                )
            } else {
                Spacer()
            }
        }
    }

    private var segmentTabs: some View {
        HStack(spacing: Spacing.s16) {
            ForEach(SearchFeature.Tab.allCases, id: \.self) { tab in
                let isSelected = store.selectedTab == tab
                Button {
                    store.send(.tabSelected(tab))
                } label: {
                    Text(tab.title)
                        .typography(.title3SB)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? Color.textPrimary : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var resultList: some View {
        ScrollView {
            switch store.selectedTab {
            case .post:
                LazyVGrid(columns: columns, spacing: Spacing.s32) {
                    ForEach(store.contents) { content in
                        ContentCard(content: content)
                    }
                }
            case .place:
                LazyVStack(spacing: Spacing.s8) {
                    ForEach(store.places) { place in
                        PlaceRow(place: place)
                    }
                }
            }
        }
    }

    private func recentChip(_ term: String) -> some View {
        HStack(spacing: Spacing.s4) {
            Text(term)
                .typography(.body1M)
                .foregroundStyle(Color.textTertiary)

            Button {
                store.send(.recentSearchDeleted(term))
            } label: {
                Image.x
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, 6)
        .background(Color.bgDefault)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.borderDefault)
        }
    }
}
