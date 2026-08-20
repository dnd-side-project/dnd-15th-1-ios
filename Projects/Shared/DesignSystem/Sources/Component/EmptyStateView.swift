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
    private let imageSize: CGFloat?
    private let imageColor: Color?
    private let title: String
    private let message: String
    private let alignment: Alignment

    public init(
        image: Image,
        imageSize: CGFloat? = nil,
        imageColor: Color? = nil,
        title: String,
        message: String,
        alignment: Alignment = .center
    ) {
        self.image = image
        self.imageSize = imageSize
        self.imageColor = imageColor
        self.title = title
        self.message = message
        self.alignment = alignment
    }

    public var body: some View {
        VStack(spacing: Spacing.s16) {
            styledImage

            VStack(spacing: Spacing.s4) {
                Text(title)
                    .typography(.title3SB)
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .typography(.body1M)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Spacing.s20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder
    private var styledImage: some View {
        if let imageSize, let imageColor {
            image
                .renderingMode(.template)
                .resizable()
                .frame(width: imageSize, height: imageSize)
                .foregroundStyle(imageColor)
        } else if let imageSize {
            image
                .resizable()
                .frame(width: imageSize, height: imageSize)
        } else if let imageColor {
            image
                .renderingMode(.template)
                .foregroundStyle(imageColor)
        } else {
            image
        }
    }
}

#Preview {
    EmptyStateView(
        image: .placeEmpty,
        title: "최근 저장된 장소가 없어요!",
        message: "다른 검색어를 입력해주세요"
    )
}

#Preview("검색 빈 화면") {
    EmptyStateView(
        image: .cancel,
        imageSize: 40,
        imageColor: Color.borderDefault,
        title: "검색 결과가 없어요",
        message: "다른 검색어를 입력해주세요",
        alignment: .top
    )
}
