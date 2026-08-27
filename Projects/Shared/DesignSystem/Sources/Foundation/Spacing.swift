//
//  Spacing.swift
//  Dulpick
//
//  Created by 이인호 on 8/6/26.
//

import CoreGraphics

// MARK: - Spacing

// 4pt 기본 단위, 4의 배수 간격
// 사용법: VStack(spacing: Spacing.s16)
public enum Spacing {
    public static let s4: CGFloat = 4
    public static let s8: CGFloat = 8
    public static let s12: CGFloat = 12
    public static let s16: CGFloat = 16
    public static let s20: CGFloat = 20
    public static let s24: CGFloat = 24
    public static let s32: CGFloat = 32
}
