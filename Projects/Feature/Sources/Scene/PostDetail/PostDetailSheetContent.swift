import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

/// 게시글 상세 시트의 본문. 본문 글과 장소 목록.
///
/// `ScrollView` 를 넣지 않는다. `MapBottomSheet` 가 자기 창 안에서 이미 스크롤한다
struct PostDetailSheetContent: View {
    let store: StoreOf<PostDetailFeature>
    /// 아래 안전영역(탭바 + 홈 인디케이터). 마지막 행이 가리지 않게 더한다
    let bottomInset: CGFloat

    var body: some View {
        Group {
            if store.isLoading {
                skeleton
            } else if store.loadFailed {
                failureState
            } else {
                loaded
            }
        }
        .padding(.bottom, Spacing.s20 + bottomInset)
        .onAppear { store.send(.onAppear) }
    }

    private var loaded: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption = store.detail?.caption, !caption.isEmpty {
                ExpandableText(
                    text: caption,
                    isExpanded: store.isExpanded
                ) {
                    store.send(.expandToggled)
                }
                .padding(.horizontal, Spacing.s20)
                .padding(.vertical, Spacing.s16)
            }

            if let places = store.detail?.places, !places.isEmpty {
                placeSection(places)
            }
        }
    }

    private func placeSection(_ places: [PostDetailPlace]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text("저장할 수 있는 곳")
                .typography(.headline)
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: Spacing.s8) {
                ForEach(places) { place in
                    PostPlaceRow(
                        place: place,
                        isSavedLocally: store.savedPlaceIDs.contains(place.id),
                        onTap: { store.send(.placeTapped(place.id)) },
                        onBookmarkTap: { store.send(.placeBookmarkTapped(place.id)) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s20)
        .padding(.vertical, Spacing.s16)
    }

    private var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< PostDetailMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: PostDetailMetric.rowCornerRadius)
                    .frame(height: PostDetailMetric.rowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s8)
    }

    /// 시트 안에서 끝낸다. 알림 띠는 지도 쪽 것이라 여기서 안 쓴다
    private var failureState: some View {
        VStack(spacing: Spacing.s16) {
            EmptyStateView(
                image: .placeEmpty,
                title: "게시글을 불러오지 못했어요",
                message: "잠시 뒤 다시 시도해주세요"
            )

            AppButton("다시 시도", style: .outlined, size: .md) {
                store.send(.retryTapped)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
    }
}
