import Foundation

// MARK: - Motion

// 사용법: .animation(.easeOut(duration: Motion.sheetDuration), value:)
public enum Motion {
    /// 시트와 그 안 내용의 등장 시점을 같은 값에 묶는다
    public static let sheetDuration: TimeInterval = 0.22
}
