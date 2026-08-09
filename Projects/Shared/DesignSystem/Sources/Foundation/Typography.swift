//
//  Typography.swift
//  Dulpick
//
//  Created by 이인호 on 8/6/26.
//

import SwiftUI

// MARK: - PretendardWeight

public enum PretendardWeight: String, Sendable {
    case regular = "Pretendard-Regular"
    case medium = "Pretendard-Medium"
    case semiBold = "Pretendard-SemiBold"
    case bold = "Pretendard-Bold"
}

public extension Font {
    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }
}

// MARK: - Typography

public struct Typography: Sendable {
    public let weight: PretendardWeight
    public let size: CGFloat
    public let lineHeightMultiple: CGFloat
    public let letterSpacingRatio: CGFloat

    public init(
        weight: PretendardWeight,
        size: CGFloat,
        lineHeightMultiple: CGFloat,
        letterSpacingRatio: CGFloat
    ) {
        self.weight = weight
        self.size = size
        self.lineHeightMultiple = lineHeightMultiple
        self.letterSpacingRatio = letterSpacingRatio
    }

    public var font: Font {
        .pretendard(weight, size: size)
    }

    public var tracking: CGFloat {
        size * letterSpacingRatio
    }

    // 폰트 기본 줄높이에 더해지는 값이라 디자인 툴 line-height 와는 근사치임
    public var lineSpacing: CGFloat {
        size * (lineHeightMultiple - 1)
    }
}

// MARK: - Typography Tokens

private extension Typography {
    // (weight, size, 행간 배수, 자간 비율)
    init(
        _ weight: PretendardWeight,
        _ size: CGFloat,
        _ lineHeight: CGFloat,
        _ letterSpacing: CGFloat
    ) {
        self.init(
            weight: weight,
            size: size,
            lineHeightMultiple: lineHeight,
            letterSpacingRatio: letterSpacing
        )
    }
}

public extension Typography {
    static let largeTitleR = Typography(.regular, 32, 1.5, -0.02)
    static let largeTitleB = Typography(.bold, 32, 1.5, -0.02)

    static let title1R = Typography(.regular, 28, 1.5, -0.02)
    static let title1B = Typography(.bold, 28, 1.5, -0.02)

    static let title2R = Typography(.regular, 22, 1.5, -0.02)
    static let title2B = Typography(.bold, 22, 1.5, -0.02)

    static let title3R = Typography(.regular, 20, 1.5, -0.02)
    static let title3SB = Typography(.semiBold, 20, 1.5, -0.02)

    static let headline = Typography(.semiBold, 18, 1.5, -0.02)

    static let body1M = Typography(.medium, 16, 1.5, -0.02)
    static let body1SB = Typography(.semiBold, 16, 1.5, -0.02)

    static let body2M = Typography(.medium, 14, 1.4, -0.01)
    static let body2SB = Typography(.semiBold, 14, 1.4, -0.01)

    static let caption1R = Typography(.regular, 13, 1.4, -0.01)
    static let caption1M = Typography(.medium, 13, 1.4, -0.01)

    static let caption2R = Typography(.regular, 12, 1.4, -0.01)
    static let caption2M = Typography(.medium, 12, 1.4, -0.01)
}

// MARK: - View + Typography

// 사용법: Text("데이트 장소 추천").typography(.largeTitleB)
public extension View {
    func typography(_ style: Typography) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
