//
//  EmptyStateView.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: EmptyStateView(title: "검색 결과가 없어요", message: "다른 검색어를 입력해주세요")
public struct EmptyStateView: View {
    private let title: String
    private let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image.cancel
                .renderingMode(.template)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.gray200)

            VStack(spacing: 4) {
                Text(title)
                    .typography(.title3SB)
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
