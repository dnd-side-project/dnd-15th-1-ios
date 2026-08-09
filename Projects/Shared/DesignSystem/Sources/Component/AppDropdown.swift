//
//  AppDropdown.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: AppDropdown(selection: $store.category, placeholder: "카테고리", options: [...])
public struct AppDropdown: View {
    @Binding private var selection: String?
    private let placeholder: String
    private let options: [String]
    @State private var isExpanded = false
    @State private var pillHeight: CGFloat = 0

    public init(
        selection: Binding<String?>,
        placeholder: String,
        options: [String]
    ) {
        self._selection = selection
        self.placeholder = placeholder
        self.options = options
    }

    private var isSelected: Bool {
        selection != nil
    }

    public var body: some View {
        pill
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { pillHeight = geo.size.height }
                }
            )
            .overlay(alignment: .topLeading) {
                if isExpanded {
                    DropdownMenu(options: options, selection: selection) { option in
                        selection = option
                        isExpanded = false
                    }
                    .fixedSize()
                    .offset(y: pillHeight + 8)
                }
            }
    }

    private var pill: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                    .typography(.body1M)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)

                (isExpanded ? Image.arrowUp : Image.arrowDown)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.bgDefault)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.textPrimary : Color.borderDefault,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
