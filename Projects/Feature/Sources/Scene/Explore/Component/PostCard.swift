//
//  PostCard.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

struct PostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Color.clear
                .aspectRatio(170.0 / 227.0, contentMode: .fit)
                .overlay {
                    RemoteImage(url: post.thumbnailURLs.first)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomLeading) {
                    placeCountBadge
                        .padding(Spacing.s8)
                }

            Text(post.title)
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
            
            Text("\(post.placeCount)")
                .typography(.body2SB)
        }
        .foregroundStyle(Color.commonWhite)
    }
}

#Preview {
    PostCard(post: Post.mocks[0])
        .frame(width: 180)
        .padding()
}
