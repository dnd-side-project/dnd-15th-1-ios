//
//  PlaceRow.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

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

            if !place.thumbnailURLs.isEmpty {
                thumbnails
            }
        }
        .padding(Spacing.s16)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bookmarkBadge: some View {
        HStack(spacing: Spacing.s4) {
            Image.bookmarkFillColor
                .resizable()
                .frame(width: 14, height: 14)
            Text("\(place.bookmarkCount)")
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.s8)
        .padding(.vertical, Spacing.s4)
        .background(Color.commonWhite)
        .clipShape(Capsule())
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s8) {
                ForEach(place.thumbnailURLs, id: \.self) { url in
                    RemoteImage(url: url)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
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
