//
//  RelatedContentCard.swift
//  Dulpick
//

import CoreImageCache
import Domain
import SharedDesignSystem
import SwiftUI

/// 상세 시트의 `장소와 관련된 게시물` 한 칸.
/// 탐색 탭 카드와 모양이 같지만 Scene 간 직접 참조를 피해 여기에 따로 둔다
struct RelatedContentCard: View {
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Color.clear
                .aspectRatio(170.0 / 227.0, contentMode: .fit)
                .overlay {
                    RemoteImage(url: content.thumbnailURLs.first)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomLeading) {
                    placeCountBadge
                        .padding(14)
                }

            Text(content.title)
                .typography(.body2M)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
        }
    }

    private var placeCountBadge: some View {
        HStack(alignment: .center, spacing: 2) {
            Image.mappin
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)

            Text("\(content.placeCount)")
                .typography(.body2SB)
        }
        .foregroundStyle(Color.commonWhite)
    }
}
