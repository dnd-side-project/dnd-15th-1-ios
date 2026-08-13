//
//  Toast.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

public struct ToastState: Equatable {
    public let message: String
    public let icon: Image?
    public let actionTitle: String?

    public init(
        message: String,
        icon: Image? = nil,
        actionTitle: String? = nil
    ) {
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
    }

    public static func == (lhs: ToastState, rhs: ToastState) -> Bool {
        lhs.message == rhs.message && lhs.actionTitle == rhs.actionTitle
    }

    public static func error(_ message: String) -> ToastState {
        ToastState(message: message, icon: .error)
    }
}

private struct ToastView: View {
    let state: ToastState
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let icon = state.icon {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 24, height: 24)
            }

            Text(state.message)
                .typography(.body1M)
                .foregroundStyle(Color.commonWhite)

            if let actionTitle = state.actionTitle {
                Button(action: onAction) {
                    Text(actionTitle)
                        .typography(.body2SB)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.gray900.opacity(0.95))
        .clipShape(Capsule())
    }
}

// MARK: - Presentation

// 사용법: .toast(item: $store.toast) { store.send(.toastActionTapped) }
// CTA 가 있는 화면: .toast(item: $store.toast, bottomInset: CTA 하단여백 + 버튼높이 + 18)
public extension View {
    func toast(
        item: Binding<ToastState?>,
        bottomInset: CGFloat = 6,
        onAction: @escaping () -> Void = {}
    ) -> some View {
        modifier(ToastModifier(item: item, bottomInset: bottomInset, onAction: onAction))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var item: ToastState?
    let bottomInset: CGFloat
    let onAction: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let state = item {
                ToastView(state: state, onAction: onAction)
                    .padding(.bottom, bottomInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: state) {
                        // 취소(새 토스트로 교체)면 이전 task 가 현재 토스트를 지우지 않게 함
                        do {
                            try await Task.sleep(for: .seconds(3))
                            item = nil
                        } catch {
                            return
                        }
                    }
            }
        }
        .animation(.easeInOut, value: item)
    }
}
