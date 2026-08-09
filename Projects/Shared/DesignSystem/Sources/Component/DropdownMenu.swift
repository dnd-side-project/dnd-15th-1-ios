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
    private let options: [String]
    private let selection: String?
    private let onSelect: (String) -> Void

    // 넘으면 스크롤
    private let visibleCount = 3

    public init(
        options: [String],
        selection: String? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.options = options
        self.selection = selection
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
        .frame(maxHeight: options.count > visibleCount ? maxHeight : nil)
        .fixedSize(horizontal: false, vertical: options.count <= visibleCount)
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
                .typography(.body1M)
                .foregroundStyle(option == selection ? Color.textPrimary : Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, 32)
                .padding(.vertical, 8)
                .background(highlight(option))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func highlight(_ option: String) -> some View {
        if option == selection {
            Color.bgSubtle
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
        }
    }

    private var maxHeight: CGFloat {
        // body1M 한 줄(약 24) + 상하 패딩 8*2 = 40, 항목 높이 근사
        CGFloat(visibleCount) * 40
    }
}
