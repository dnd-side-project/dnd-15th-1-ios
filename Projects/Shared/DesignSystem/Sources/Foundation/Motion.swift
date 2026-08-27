import SwiftUI

// MARK: - Motion

public enum Motion {
    /// 시트와 그 안 내용의 등장 시점을 같은 값에 묶는다
    public static let sheetDuration: TimeInterval = 0.3
    /// 시스템 시트처럼 부드럽게 오르내린다. 지도 시트의 짧은 붙기 스프링과는 다르다
    public static let sheetSpring: Animation = .smooth(duration: sheetDuration)
}
