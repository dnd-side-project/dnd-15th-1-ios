//
//  PlaceOwnership+Extension.swift
//  Dulpick
//
//  Created by 이인호 on 8/18/26.
//

import Domain

/// Domain `PlaceOwnership` 은 서버 값만 갖고 한글 이름을 모른다.
/// 화면에 필요한 것만 Feature 쪽에서 붙인다.
public extension PlaceOwnership {
    /// 시트 드롭다운이 쓰는 차례. `함께 저장한` 이 맨 앞이다
    static let mapDisplayOrder: [PlaceOwnership] = [.together, .mine, .partner]

    var displayName: String {
        switch self {
        case .together: "함께 저장한"
        case .mine: "내가 저장한"
        case .partner: "상대가 저장한"
        }
    }

    /// `AppDropdown` 이 문자열만 주고받아 되돌리는 길이 필요하다.
    static func fromDisplayName(_ name: String) -> PlaceOwnership? {
        mapDisplayOrder.first { $0.displayName == name }
    }

    /// 이 값을 **필터로 썼을 때** `ownership` 인 장소를 담는지.
    ///
    /// 받는 쪽이 필터고 인자가 장소의 값이다. 두 자리를 바꿔 쓰면 조용히 틀린 답이 나온다.
    /// `.together` 는 아무것도 안 거른다. 필터 자리에서는 "전체" 를 뜻한다.
    /// `.mine` 은 둘 다 저장한 장소까지 담는다. 그것도 내가 저장한 것이기 때문이다.
    func matches(_ ownership: PlaceOwnership) -> Bool {
        switch self {
        case .together: true
        case .mine: ownership == .mine || ownership == .together
        case .partner: ownership == .partner || ownership == .together
        }
    }
}
