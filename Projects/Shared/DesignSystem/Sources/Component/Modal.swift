//
//  Modal.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import SwiftUI

public struct ModalContent: View {
    private let title: String
    private let content: String
    private let image: Image?
    private let primaryTitle: String
    private let primaryAction: () -> Void
    private let secondaryTitle: String?
    private let secondaryAction: (() -> Void)?

    public init(
        title: String,
        content: String,
        image: Image? = nil,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.content = content
        self.image = image
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .typography(.title2B)
                .foregroundStyle(Color.gray900)

            Text(content)
                .typography(.body1M)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 8)

            // 위치 권한 안내처럼 넣을 그림이 없는 자리를 위해서다
            if let image {
                image
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(.top, 20)
            }

            buttons
                .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(Color.commonWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            if let secondaryTitle, let secondaryAction {
                AppButton(
                    secondaryTitle,
                    style: .outlined,
                    size: .xl,
                    fullWidth: true,
                    action: secondaryAction
                )
            }
            AppButton(
                primaryTitle,
                style: .dark,
                size: .xl,
                fullWidth: true,
                action: primaryAction
            )
        }
    }
}

// MARK: - Presentation

// 사용법: .modal(isPresented: $store.isPresented) { ModalContent(...) }
public extension View {
    func modal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // 페이드로 뜨는 오버레이. dim 은 페이드, 카드는 확대 + 페이드
        // zIndex 를 적지 않으면 닫히는 동안 카드가 dim 밑으로 내려가 한 프레임에 어두워진다
        overlay {
            ZStack {
                if isPresented.wrappedValue {
                    Color.dimBackground
                        .ignoresSafeArea()
                        .onTapGesture { isPresented.wrappedValue = false }
                        .transition(.opacity)
                        .zIndex(0)

                    content()
                        .padding(.horizontal, 20)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            // 들어올 때보다 나갈 때를 짧게. 값이 바뀐 뒤의 상태로 평가된다
            // 오버레이 안에 둬야 애니메이션이 아래 화면까지 번지지 않는다
            .animation(
                .easeOut(duration: isPresented.wrappedValue ? 0.2 : 0.16),
                value: isPresented.wrappedValue
            )
            .accessibilityAddTraits(isPresented.wrappedValue ? .isModal : [])
        }
    }
}
