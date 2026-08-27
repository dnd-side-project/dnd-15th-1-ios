import SwiftUI

// MARK: - SheetDragEnvironment

private struct SheetDraggingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// 시트가 지금 손짓을 들고 있는지.
    ///
    /// 시트 안에 든 가로 스크롤이 이 값을 읽어 스스로 잠근다.
    /// `scrollDisabled` 는 시트 본문의 세로 스크롤에만 닿고 그 안쪽 가로 스크롤에는 안 닿는다
    var isSheetDragging: Bool {
        get { self[SheetDraggingKey.self] }
        set { self[SheetDraggingKey.self] = newValue }
    }
}
