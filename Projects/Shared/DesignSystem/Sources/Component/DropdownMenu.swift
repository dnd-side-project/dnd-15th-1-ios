//
//  DropdownMenu.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//
//  단독(··· 메뉴)으로도, AppDropdown 내부 펼침 카드로도 사용
//

import SwiftUI

// 사용법: DropdownMenu(options: ["A", "B"], selection: sel) { onSelect($0) }
public struct DropdownMenu: View {

    /// 쓰이는 두 자리의 시안 치수가 서로 달라 모양을 나눈다.
    public enum Style {
        /// 필터 칩 아래 펼쳐지는 목록
        case dropdown
        /// 행 오른쪽 `⋮` 로 여는 작업 목록
        case menu
    }

    private let options: [String]
    private let selection: String?
    private let style: Style
    private let onSelect: (String) -> Void

    // 넘으면 스크롤
    private let visibleCount = 3

    public init(
        options: [String],
        selection: String? = nil,
        style: Style = .dropdown,
        onSelect: @escaping (String) -> Void
    ) {
        self.options = options
        self.selection = selection
        self.style = style
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    item(option)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: options.count > visibleCount ? maxHeight : nil)
        .fixedSize(horizontal: false, vertical: options.count <= visibleCount)
        // 스크롤 영역 바깥에 걸어야 스크롤할 때 여백이 같이 밀려 올라가지 않는다.
        .padding(style.contentPadding)
        .background(Color.bgDefault)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderDefault, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func item(_ option: String) -> some View {
        Button {
            onSelect(option)
        } label: {
            Text(option)
                .typography(style.typography)
                .foregroundStyle(textColor(option))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, style.leadingPadding)
                .padding(.trailing, style.trailingPadding)
                .padding(.vertical, style.verticalPadding)
                .background(highlight(option))
        }
        .buttonStyle(.plain)
    }

    /// `.menu` 는 고른 항목이라는 개념이 없다.
    private func textColor(_ option: String) -> Color {
        switch style {
        case .dropdown:
            return option == selection ? Color.textPrimary : Color.textSecondary

        case .menu:
            return Color.textPrimary
        }
    }

    @ViewBuilder
    private func highlight(_ option: String) -> some View {
        if style == .dropdown, option == selection {
            // 좌우로 좁히지 않는다. 카드의 `contentPadding` 이 그 자리를 대신한다.
            Color.bgSubtle
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var maxHeight: CGFloat {
        CGFloat(visibleCount) * style.itemHeight
    }
}

// MARK: - Style Metric

private extension DropdownMenu.Style {

    var typography: Typography {
        switch self {
        case .dropdown:
            return .body1M

        case .menu:
            return .body2M
        }
    }

    /// 카드 테두리와 항목 사이 사방 여백. `.menu` 는 항목이 테두리에 붙는다.
    var contentPadding: CGFloat {
        switch self {
        case .dropdown:
            return 4

        case .menu:
            return 0
        }
    }

    var leadingPadding: CGFloat { 16 }

    var trailingPadding: CGFloat {
        switch self {
        case .dropdown:
            return 32

        case .menu:
            return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .dropdown:
            return 8

        case .menu:
            return 12
        }
    }

    /// 스크롤 한계를 재는 항목 높이 근사.
    /// `.dropdown` 은 body1M 한 줄(약 24) + 상하 8 = 40, `.menu` 는 body2M 한 줄(약 20) + 상하 12 = 44.
    var itemHeight: CGFloat {
        switch self {
        case .dropdown:
            return 40

        case .menu:
            return 44
        }
    }
}
