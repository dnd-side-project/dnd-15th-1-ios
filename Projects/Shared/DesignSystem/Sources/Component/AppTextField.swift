//
//  AppTextField.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: AppTextField(text: $text, placeholder: "닉네임", size: .large, style: .outlined, accessory: .clear, errorMessage: error)
public struct AppTextField: View {
    public enum Size {
        case large
        case medium
    }

    public enum Style {
        case filled
        case outlined
    }

    public enum Accessory {
        case none
        case search
        case clear
    }

    @Binding private var text: String
    private let placeholder: String
    private let size: Size
    private let style: Style
    private let accessory: Accessory
    private let errorMessage: String?

    public init(
        text: Binding<String>,
        placeholder: String,
        size: Size = .large,
        style: Style = .filled,
        accessory: Accessory = .none,
        errorMessage: String? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.size = size
        self.style = style
        self.accessory = accessory
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field

            if let errorMessage {
                Text(errorMessage)
                    .typography(.caption1M)
                    .foregroundStyle(Color.statusError)
                    .padding(.leading, 8)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .typography(.body1M)
                .foregroundStyle(Color.gray900)

            accessoryView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, size.verticalPadding)
        .frame(height: size.height)
        .background(style == .filled ? Color.gray50 : Color.bgDefault)
        .clipShape(RoundedRectangle(cornerRadius: size.radius))
        .overlay {
            if style == .outlined {
                RoundedRectangle(cornerRadius: size.radius)
                    .strokeBorder(Color.borderDefault, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .search:
            Image.search
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.textTertiary)
        case .clear:
            Button {
                text = ""
            } label: {
                Image.x
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

private extension AppTextField.Size {
    var height: CGFloat {
        switch self {
        case .large: 56
        case .medium: 48
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large: 16
        case .medium: 12
        }
    }

    var radius: CGFloat {
        switch self {
        case .large: 16
        case .medium: 12
        }
    }
}
