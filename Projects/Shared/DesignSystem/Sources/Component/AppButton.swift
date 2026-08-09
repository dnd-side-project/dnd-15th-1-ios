//
//  AppButton.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: AppButton("다음", icon: .someIcon, style: .primary, size: .xl, fullWidth: true) { }
public struct AppButton: View {
    private let title: String
    private let icon: Image?
    private let style: AppButtonStyle.Variant
    private let size: AppButtonStyle.Size
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        icon: Image? = nil,
        style: AppButtonStyle.Variant,
        size: AppButtonStyle.Size,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    // 크기는 애셋 원본, 색은 버튼 텍스트색을 따라감
                    icon.renderingMode(.template)
                }
                Text(title)
            }
        }
        .buttonStyle(AppButtonStyle(variant: style, size: size, fullWidth: fullWidth))
    }
}
