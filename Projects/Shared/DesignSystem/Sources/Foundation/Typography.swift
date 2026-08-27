//
//  Typography.swift
//  Dulpick
//
//  Created by 이인호 on 8/6/26.
//

import SwiftUI
import UIKit

// MARK: - PretendardWeight

/// PostScript 이름이자 `Resources/Fonts/` 의 `.otf` 파일명 stem. 어긋나면 등록은 되지만 조회가 안 된다.
public enum PretendardWeight: String, CaseIterable, Sendable {
    case regular = "Pretendard-Regular"
    case medium = "Pretendard-Medium"
    case semiBold = "Pretendard-SemiBold"
    case bold = "Pretendard-Bold"
}

// MARK: - PretendardFontRegistry

private enum PretendardFontRegistry {
    static func fontName(for weight: PretendardWeight) -> String {
        // 이 접근이 등록을 발화시킨다. 지우면 폰트가 조용히 시스템 폰트로 폴백한다.
        _ = registerFontsOnce
        return weight.rawValue
    }

    // 생성된 `swiftUIFont(size:)` 접근자는 실패 시 `fatalError` 라 `registerAllCustomFonts()` 만 쓴다.
    private static let registerFontsOnce: Void = {
        SharedDesignSystemFontFamily.registerAllCustomFonts()
        #if DEBUG
        let missing = PretendardWeight.allCases.filter { UIFont(name: $0.rawValue, size: 12) == nil }
        assert(missing.isEmpty, "Pretendard 등록 실패: \(missing.map(\.rawValue))")
        #endif
    }()
}

public extension Font {
    /// 프레임워크 리소스라 `UIAppFonts` 로는 등록되지 않는다. 이 호출이 앱·프리뷰·테스트 공통 등록 지점이다.
    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(PretendardFontRegistry.fontName(for: weight), size: size)
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

    /// Pretendard 네 굵기가 공유하는 줄높이 배수.
    /// `.otf` 실측 — unitsPerEm 2048, ascender 1950, descender -494, lineGap 0
    private static let fontLineHeightRatio: CGFloat = (1950 + 494) / 2048.0

    // SwiftUI `.lineSpacing` 은 폰트 기본 줄높이 위에 더하므로, 시안 배수에서 폰트 메트릭 배수를 뺀다
    public var lineSpacing: CGFloat {
        max(0, size * (lineHeightMultiple - Self.fontLineHeightRatio))
    }

    /// 시안이 잡는 글자 한 줄 상자 높이 (`size * lineHeightMultiple`).
    /// `lineSpacing` 은 줄 사이에 더하는 값이고, 이건 한 줄이 차지하는 상자 자체다.
    public var lineHeight: CGFloat {
        size * lineHeightMultiple
    }

    /// UIKit 으로 그리는 입력칸이 SwiftUI 쪽과 같은 글꼴을 쓰게 하는 통로.
    /// 등록이 실패해도 화면이 비지 않도록 시스템 폰트로 떨어진다
    public var uiFont: UIFont {
        UIFont(name: PretendardFontRegistry.fontName(for: weight), size: size)
            ?? .systemFont(ofSize: size, weight: weight.uiFontWeight)
    }
}

private extension PretendardWeight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semiBold: .semibold
        case .bold: .bold
        }
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
