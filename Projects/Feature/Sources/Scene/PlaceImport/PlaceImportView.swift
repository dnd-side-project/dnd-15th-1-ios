//
//  PlaceImportView.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct PlaceImportView: View {
    @Bindable public var store: StoreOf<PlaceImportFeature>
    @State private var currentPage: Int?

    public init(store: StoreOf<PlaceImportFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(Color.commonWhite)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            loadingView
        case .loaded:
            loadedView
        case .failed:
            failedView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            Text("장소를 추출중이에요")
                .typography(.title2B)
                .foregroundStyle(Color.gray900)

            Text("잠시만 기다려주세요")
                .typography(.body1M)
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 8)

            ProgressView()
                .controlSize(.large)
                .padding(.vertical, 33)
                .padding(.top, 20)
        }
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("장소를 추출할 수 없어요!")
                    .typography(.title2B)
                    .foregroundStyle(Color.textPrimary)

                Text("다른 게시물 링크로 공유해보세요")
                    .typography(.body1M)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image.placeEmpty
                .padding(.top, 33)
                .padding(.bottom, 40)

            AppButton("닫기", style: .dark, size: .xl, fullWidth: true) {
                store.send(.closeTapped)
            }
        }
    }

    // MARK: - Loaded

    private var loadedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            loadedHeader

            placesPager
                .padding(.top, 8)

            ImportPageIndicator(pageCount: pages.count, currentPage: currentPage ?? 0)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            saveButton
                .padding(.top, 20)
        }
    }

    private var loadedHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .typography(.title2B)
                .foregroundStyle(Color.gray900)

            originButton
                .padding(.top, 8)

            (
                Text("저장 가능한 장소 ")
                    .foregroundColor(Color.textPrimary)
                    + Text("\(store.candidates.count)곳")
                    .foregroundColor(Color.brandPrimary)
            )
            .typography(.headline)
            .padding(.top, 24)
        }
    }

    private var originButton: some View {
        Button {} label: {
            HStack(spacing: 4) {
                Image.insta
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("원문보기")
                    .typography(.caption1M)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray200, lineWidth: 1)
            }
        }
    }

    private var placesPager: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 8) {
                        ForEach(page) { candidate in
                            CandidateRow(
                                candidate: candidate,
                                isSelected: store.selectedIDs.contains(candidate.id)
                            ) {
                                store.send(.candidateToggled(candidate.id))
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $currentPage)
    }

    private var saveButton: some View {
        AppButton(saveTitle, style: .dark, size: .xl, fullWidth: true) {
            store.send(.saveTapped)
        }
        .disabled(store.selectedIDs.isEmpty)
    }

    // MARK: - Derived

    private var title: String {
        if case let .loaded(placeImport) = store.phase {
            return placeImport.content.title ?? ""
        }
        return ""
    }

    private var pages: [[ImportCandidate]] {
        let candidates = store.candidates
        return stride(from: 0, to: candidates.count, by: 4).map { start in
            Array(candidates[start..<min(start + 4, candidates.count)])
        }
    }

    private var saveTitle: String {
        store.isAllSelected ? "모두 저장" : "\(store.selectedIDs.count)곳만 저장"
    }
}
