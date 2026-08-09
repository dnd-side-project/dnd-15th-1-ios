//
//  AppButtonStyle.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

public struct AppButtonStyle: ButtonStyle {
    public enum Variant {
        case primary
        case dark
        case outlined
    }

    public enum Size {
        case xl
        case lg
        case md
        case sm
    }

    let variant: Variant
    let size: Size
    let fullWidth: Bool

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(
            variant: variant,
            size: size,
            fullWidth: fullWidth,
            configuration: configuration
        )
    }

    private struct StyledLabel: View {
        let variant: Variant
        let size: Size
        let fullWidth: Bool
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .typography(size.typography)
                .foregroundStyle(foreground)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: size.radius))
                .overlay {
                    if variant == .outlined {
                        RoundedRectangle(cornerRadius: size.radius)
                            .strokeBorder(Color.borderDefault, lineWidth: 1)
                    }
                }
                .opacity(configuration.isPressed ? 0.9 : 1)
        }

        private var background: Color {
            switch (variant, isEnabled) {
            case (.primary, true): .primaryPink
            case (.dark, true): .gray900
            case (.outlined, true): .commonWhite
            case (.primary, false), (.dark, false): .gray100
            case (.outlined, false): .gray50
            }
        }

        private var foreground: Color {
            switch (variant, isEnabled) {
            case (.primary, true), (.dark, true): .textInverse
            case (.outlined, true): .textSecondary
            case (.primary, false), (.dark, false): .gray400
            case (.outlined, false): .gray300
            }
        }
    }
}

private extension AppButtonStyle.Size {
    var radius: CGFloat {
        self == .sm ? 8 : 12
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .xl, .lg: 24
        case .md: 20
        case .sm: 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .xl: 16
        case .lg: 12
        case .md: 8
        case .sm: 7
        }
    }

    var typography: Typography {
        switch self {
        case .xl, .lg: .body1SB
        case .md: .body1M
        case .sm: .caption1M
        }
    }
}
