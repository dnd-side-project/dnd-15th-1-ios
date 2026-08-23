//
//  UINavigationController+Extension.swift
//  Dulpick
//
//  Created by 이인호 on 8/8/26.
//

import SwiftUI
import UIKit

// 커스텀 back 버튼(navigationBarBackButtonHidden) 사용 시 스와이프 뒤로가기 복원
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    // 쓸어서 닫으면 「변경사항을 저장할까요?」 모달을 건너뛴다
    @MainActor
    fileprivate static var isBlockingSwipeBack = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && !Self.isBlockingSwipeBack
    }
}

// MARK: - BlocksSwipeBack

private struct BlocksSwipeBackModifier: ViewModifier {
    let isBlocked: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { UINavigationController.isBlockingSwipeBack = isBlocked }
            .onChange(of: isBlocked) { _, isBlocked in
                UINavigationController.isBlockingSwipeBack = isBlocked
            }
            // 앱 전체에 걸리므로 이 화면이 어떤 길로 닫히든 반드시 끈다
            .onDisappear { UINavigationController.isBlockingSwipeBack = false }
    }
}

extension View {
    func blocksSwipeBack(_ isBlocked: Bool) -> some View {
        modifier(BlocksSwipeBackModifier(isBlocked: isBlocked))
    }
}
