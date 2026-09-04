//
//  PlaceRow.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import CoreImageCache
import Domain
import SharedDesignSystem
import SwiftUI

struct PlaceRow: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(spacing: Spacing.s8) {
                place.category.icon
                    .resizable()
                    .frame(width: 24, height: 24)

                Text(place.name)
                    .typography(.body1M)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                bookmarkBadge
            }
            .padding(.horizontal, Spacing.s20)

            if !place.thumbnailURLs.isEmpty {
                thumbnails
            }
        }
        .padding(.vertical, Spacing.s16)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bookmarkBadge: some View {
        HStack(spacing: 2) {
            Image.bookmarkFillColor
                .resizable()
                .frame(width: 14, height: 14)
            Text("\(place.bookmarkCount)")
                .typography(.body2SB)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.s8)
        .padding(.vertical, Spacing.s4)
        .background(Color.commonWhite)
        .clipShape(Capsule())
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s4) {
                ForEach(Array(place.thumbnailURLs.enumerated()), id: \.offset) { _, url in
                    RemoteImage(url: url)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, Spacing.s20)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.s12) {
        PlaceRow(place: Place.mocks[0])
        PlaceRow(place: Place.mocks[1])
    }
    .padding()
}
