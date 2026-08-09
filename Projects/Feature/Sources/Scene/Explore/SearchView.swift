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

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            searchField
            recentSection
            Spacer()
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s20)
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
        HStack(spacing: Spacing.s8) {
            TextField("원하는 장소를 검색해보세요", text: $store.query)
                .typography(.body2M)
                .foregroundStyle(Color.gray400)

            Image.search
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.vertical, Spacing.s16)
        .background(Color.gray50)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 20)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            HStack {
                Text("최근 검색어")
                    .typography(.body1SB)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s8) {
                    ForEach(store.recentSearches, id: \.self) { term in
                        recentChip(term)
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
