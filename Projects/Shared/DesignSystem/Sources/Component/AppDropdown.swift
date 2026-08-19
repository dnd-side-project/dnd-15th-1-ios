//
//  AppDropdown.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

// 사용법: AppDropdown(selection: $store.category, isExpanded: $isOpen, placeholder: "카테고리", options: [...])
public struct AppDropdown: View {
    @Binding private var selection: String?
    @Binding private var isExpanded: Bool
    private let placeholder: String
    private let options: [String]
    private let onMenuFrameChange: ((CGRect?) -> Void)?
    @State private var pillHeight: CGFloat = 0

    public init(
        selection: Binding<String?>,
        isExpanded: Binding<Bool>,
        placeholder: String,
        options: [String],
        onMenuFrameChange: ((CGRect?) -> Void)? = nil
    ) {
        self._selection = selection
        self._isExpanded = isExpanded
        self.placeholder = placeholder
        self.options = options
        self.onMenuFrameChange = onMenuFrameChange
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
                    // 아래 .offset 까지 반영된 자리가 나온다. 손으로 더하면 그만큼 아래로 밀린다
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        onMenuFrameChange?(frame)
                    }
                    .offset(y: pillHeight + 8)
                    .onDisappear {
                        onMenuFrameChange?(nil)
                    }
                }
            }
            .onChange(of: isExpanded) { _, expanded in
                if !expanded {
                    onMenuFrameChange?(nil)
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
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isSelected ? Color.bgSubtle : Color.bgDefault)
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
