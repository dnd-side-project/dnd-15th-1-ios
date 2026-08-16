import UIKit

/// 지금 편집 중인 곳이 어디든 편집을 끝내 키보드를 내린다.
///
/// `SanitizingTextField` 의 `isFocused` 바인딩만으로는 부족하다. 그쪽 동기화는
/// `wantsFocus != uiView.isFirstResponder` 일 때만 움직여서, 화면이 밀려나는 동안 iOS 가 첫 응답자를
/// 잠시 거둬 가면 "이미 놓았다" 로 보고 건너뛴다. 우리가 명시적으로 끝낸 적이 없으니 iOS 는 돌아올 때
/// 자기 기록대로 되살린다. 그래서 응답자가 누구든 상관없이 끊는 통로를 따로 둔다
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}
