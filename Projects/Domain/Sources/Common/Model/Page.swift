import Foundation

/// 쪽 나눈 목록 한 장. hasNext 로만 다음 쪽 유무 판단
public struct Page<Item: Equatable & Sendable>: Equatable, Sendable {
    public let items: [Item]
    public let hasNext: Bool

    public init(items: [Item], hasNext: Bool) {
        self.items = items
        self.hasNext = hasNext
    }
}
