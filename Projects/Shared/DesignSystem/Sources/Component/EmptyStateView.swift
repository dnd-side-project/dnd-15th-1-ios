//
//  EmptyStateView.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: EmptyStateView(image: .placeEmpty, title: "저장된 장소가 없어요!", message: "장소를 저장해보세요")
public struct EmptyStateView: View {
    private let image: Image
    private let title: String
    private let message: String

    public init(image: Image, title: String, message: String) {
        self.image = image
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            image

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
    EmptyStateView(
        image: .placeEmpty,
        title: "최근 저장된 장소가 없어요!",
        message: "다른 검색어를 입력해주세요"
    )
}
