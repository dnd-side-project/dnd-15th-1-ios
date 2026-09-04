//
//  ContentCard.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import CoreImageCache
import Domain
import SharedDesignSystem
import SwiftUI

struct ContentCard: View {
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Color.clear
                .aspectRatio(170.0 / 227.0, contentMode: .fit)
                .overlay {
                    RemoteImage(url: content.thumbnailURLs.first, placeholderImage: .placeEmpty)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomLeading) {
                    placeCountBadge
                        .padding(.leading, 14)
                        .padding(.bottom, 14)
                }

            Text(content.title)
                .typography(.body2M)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
        }
    }

    private var placeCountBadge: some View {
        HStack(spacing: 2) {
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

#Preview {
    ContentCard(content: Content.mocks[0])
        .frame(width: 180)
        .padding()
}
