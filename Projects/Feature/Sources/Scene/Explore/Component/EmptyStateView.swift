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
        VStack(spacing: Spacing.s12) {
            Image.cancel
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.gray300)
            Text(title)
                .typography(.body1SB)
                .foregroundStyle(Color.textSecondary)
            Text(message)
                .typography(.caption1R)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(title: "검색 결과가 없어요", message: "다른 검색어를 입력해주세요")
}
