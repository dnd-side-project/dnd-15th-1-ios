//
//  UINavigationController+Extension.swift
//  Dulpick
//
//  Created by 이인호 on 8/8/26.
//

import UIKit

// 커스텀 back 버튼(navigationBarBackButtonHidden) 사용 시 스와이프 뒤로가기 복원
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
