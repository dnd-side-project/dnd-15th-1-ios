//
//  EmptyStateView.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import SharedDesignSystem
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.s16) {
            Image.cancel
                .renderingMode(.template)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.gray200)

            VStack(spacing: Spacing.s4) {
                Text(title)
                    .typography(.title3B)
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .typography(.body1M)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(title: "검색 결과가 없어요", message: "다른 검색어를 입력해주세요")
}
