//
//  SavedPlaceRow.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

struct SavedPlaceRow: View {
    let place: SavedPlace

    var body: some View {
        HStack(spacing: 8) {
            place.place.category.icon
                .resizable()
                .frame(width: 24, height: 24)

            Text(place.place.name)
                .typography(.body1M)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
