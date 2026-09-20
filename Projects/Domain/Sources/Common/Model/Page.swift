import Foundation

/// 페이지로 나뉜 목록의 한 페이지. hasNext 로만 다음 페이지 유무 판단
public struct Page<Item: Equatable & Sendable>: Equatable, Sendable {
    public let items: [Item]
    public let hasNext: Bool

    public init(items: [Item], hasNext: Bool) {
        self.items = items
        self.hasNext = hasNext
    }
}
