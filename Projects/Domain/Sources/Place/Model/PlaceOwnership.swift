import Foundation

/// 현재 커플 기준 저장 관계. 서버 `ownershipStatus` 문자열 변환은 Data 가 맡는다
public enum PlaceOwnership: Equatable, Sendable, CaseIterable {
    case mine
    case partner
    case together
}
