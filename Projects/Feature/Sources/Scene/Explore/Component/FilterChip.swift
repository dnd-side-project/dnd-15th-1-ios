//
//  FilterChip.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import SharedDesignSystem
import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(.body1M)
                .foregroundStyle(isSelected ? Color.textInverse : Color.textSecondary)
                .padding(.horizontal, Spacing.s20)
                .padding(.vertical, Spacing.s8)
                .background(isSelected ? Color.gray900 : Color.bgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: Spacing.s8) {
        FilterChip(title: "인기", isSelected: true) {}
        FilterChip(title: "#성수", isSelected: false) {}
    }
    .padding()
}
