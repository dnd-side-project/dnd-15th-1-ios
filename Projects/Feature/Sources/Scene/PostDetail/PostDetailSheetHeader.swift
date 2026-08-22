import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

/// 게시글 상세 시트의 머리. 제목 · 닫기 · 인스타 버튼
struct PostDetailSheetHeader: View {
    let store: StoreOf<PostDetailFeature>
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(alignment: .top, spacing: Spacing.s8) {
                // 부르는 중에는 줄을 안 그린다. `제목없음` 이 스쳤다 바뀌면 깜빡이는 것처럼 보인다
                if let detail = store.detail {
                    Text(displayTitle(of: detail))
                        .typography(.title3SB)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, PostDetailMetric.titleVerticalSpacing)
                } else {
                    Spacer(minLength: 0)
                }

                closeButton
            }

            if store.detail?.canonicalURL != nil {
                instagramButton
            }
        }
        .padding(.leading, Spacing.s20)
        .padding(.trailing, Spacing.s12)
    }

    /// 원본에 제목이 없거나 빈 글자면 없음을 알린다. 자리를 비우지 않는다
    private func displayTitle(of detail: PostDetailContent) -> String {
        guard let title = detail.title, !title.isEmpty else { return "제목없음" }
        return title
    }

    private var closeButton: some View {
        Button {
            store.send(.closeTapped)
        } label: {
            Image.x
                .renderingMode(.template)
                .resizable()
                .frame(width: PostDetailMetric.iconSize, height: PostDetailMetric.iconSize)
                .foregroundStyle(Color.textTertiary)
                .frame(
                    width: PostDetailMetric.closeButtonSize,
                    height: PostDetailMetric.closeButtonSize
                )
        }
        .buttonStyle(.plain)
    }

    private var instagramButton: some View {
        Button {
            if let url = store.detail?.canonicalURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: PostDetailMetric.instagramIconGap) {
                Image.insta
                    .resizable()
                    .frame(
                        width: PostDetailMetric.instagramIconSize,
                        height: PostDetailMetric.instagramIconSize
                    )
                Text("원문보기")
                    .typography(.caption1M)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, PostDetailMetric.instagramVerticalPadding)
            .overlay {
                RoundedRectangle(cornerRadius: PostDetailMetric.instagramCornerRadius)
                    .strokeBorder(Color.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
