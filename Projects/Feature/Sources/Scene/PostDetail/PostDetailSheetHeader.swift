//
//  PostDetailSheetHeader.swift
//  Dulpick
//

import SharedDesignSystem
import SwiftUI
import ThirdParty

/// 게시글 상세 시트의 머리. 제목 · 닫기 · 인스타 버튼
struct PostDetailSheetHeader: View {
    let store: StoreOf<PostDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(alignment: .top, spacing: Spacing.s8) {
                // 제목이 없으면 줄을 안 그린다. 닫기 버튼은 남는다
                if let title = store.detail?.title {
                    Text(title)
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
            store.send(.instagramTapped)
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
