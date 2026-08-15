//
//  AppTextField.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI
import UIKit

// 사용법: AppTextField(text: $text, placeholder: "닉네임", accessory: .clear, submitLabel: .search, onSubmit: { ... })
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
    private let submitLabel: SubmitLabel
    private let sanitize: ((String) -> String)?
    private let isFocused: Binding<Bool>?
    private let onSubmit: (() -> Void)?

    /// - Parameters:
    ///   - sanitize: 주면 입력이 들어오기 전에 이 규칙으로 걸러 UIKit 입력칸으로 그린다.
    ///     한글 조합 중에는 SwiftUI 바인딩으로 되돌린 값이 입력칸에 닿지 않아 글자수 제한이 새기 때문이다.
    ///     이 경우 리턴 키는 완료 고정이고 `submitLabel` 은 쓰이지 않는다
    ///   - isFocused: `sanitize` 를 준 경우의 포커스 통로. UIKit 입력칸은 `.focused` 로 잡히지 않는다
    public init(
        text: Binding<String>,
        placeholder: String,
        size: Size = .large,
        style: Style = .filled,
        accessory: Accessory = .none,
        errorMessage: String? = nil,
        submitLabel: SubmitLabel = .done,
        sanitize: ((String) -> String)? = nil,
        isFocused: Binding<Bool>? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.size = size
        self.style = style
        self.accessory = accessory
        self.errorMessage = errorMessage
        self.submitLabel = submitLabel
        self.sanitize = sanitize
        self.isFocused = isFocused
        self.onSubmit = onSubmit
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
            input

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
    private var input: some View {
        if let sanitize {
            SanitizingTextField(
                text: $text,
                placeholder: placeholder,
                typography: .body1M,
                textColor: UIColor(Color.gray900),
                isFocused: isFocused,
                sanitize: sanitize,
                onSubmit: onSubmit
            )
        } else {
            TextField(placeholder, text: $text)
                .typography(.body1M)
                .foregroundStyle(Color.gray900)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
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
