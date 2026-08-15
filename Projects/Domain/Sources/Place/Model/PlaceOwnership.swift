import Foundation

/// 현재 커플 기준 저장 관계. 서버 `ownershipStatus` 와 1:1.
public enum PlaceOwnership: String, Equatable, Sendable, CaseIterable {
    case mine
    case partner
    case together
}
