//
//  Color.swift
//  Dulpick
//
//  Created by 이인호 on 8/6/26.
//

import SwiftUI

private typealias Asset = SharedDesignSystemAsset

// MARK: - Primitive

// 사용법: Text("...").foregroundStyle(.gray900)
public extension ShapeStyle where Self == Color {

    // Grayscale
    static var gray900: Color { Asset.gray900.swiftUIColor }
    static var gray800: Color { Asset.gray800.swiftUIColor }
    static var gray700: Color { Asset.gray700.swiftUIColor }
    static var gray600: Color { Asset.gray600.swiftUIColor }
    static var gray500: Color { Asset.gray500.swiftUIColor }
    static var gray400: Color { Asset.gray400.swiftUIColor }
    static var gray300: Color { Asset.gray300.swiftUIColor }
    static var gray200: Color { Asset.gray200.swiftUIColor }
    static var gray100: Color { Asset.gray100.swiftUIColor }
    static var gray50: Color { Asset.gray50.swiftUIColor }

    // Primary
    static var primaryPink: Color { Asset.primaryPink.swiftUIColor }

    // Common
    static var commonBlack: Color { Asset.commonBlack.swiftUIColor }
    static var commonWhite: Color { Asset.commonWhite.swiftUIColor }

    // Category
    static var categoryOrange: Color { Asset.categoryOrange.swiftUIColor }
    static var categoryYellow: Color { Asset.categoryYellow.swiftUIColor }
    static var categoryLightGreen: Color { Asset.categoryLightGreen.swiftUIColor }
    static var categoryGreen: Color { Asset.categoryGreen.swiftUIColor }
    static var categorySkyBlue: Color { Asset.categorySkyBlue.swiftUIColor }
    static var categoryBlue: Color { Asset.categoryBlue.swiftUIColor }
    static var categoryPurple: Color { Asset.categoryPurple.swiftUIColor }
}

// MARK: - Semantic

public extension ShapeStyle where Self == Color {

    // Brand
    static var brandPrimary: Color { Asset.brandPrimary.swiftUIColor }

    // Text
    static var textPrimary: Color { Asset.textPrimary.swiftUIColor }
    static var textSecondary: Color { Asset.textSecondary.swiftUIColor }
    static var textTertiary: Color { Asset.textTertiary.swiftUIColor }
    static var textDisabled: Color { Asset.textDisabled.swiftUIColor }
    static var textInverse: Color { Asset.textInverse.swiftUIColor }
    static var textInverseTertiary: Color { Asset.textInverseTertiary.swiftUIColor }

    // Bg
    static var bgDefault: Color { Asset.bgDefault.swiftUIColor }
    static var bgSubtle: Color { Asset.bgSubtle.swiftUIColor }

    // Surface
    static var surfaceCard: Color { Asset.surfaceCard.swiftUIColor }

    // Border
    static var borderDefault: Color { Asset.borderDefault.swiftUIColor }
    static var borderWeak: Color { Asset.borderWeak.swiftUIColor }

    // Status
    static var statusError: Color { Asset.statusError.swiftUIColor }
}
