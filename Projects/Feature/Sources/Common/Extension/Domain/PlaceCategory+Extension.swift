//
//  PlaceCategory+Extension.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import SharedDesignSystem
import SwiftUI
import UIKit

/// Domain `PlaceCategory` 는 서버 값만 갖고 한글 이름을 모른다.
/// 화면에 필요한 것만 Feature 쪽에서 붙인다.
extension PlaceCategory {
    var icon: Image {
        switch self {
        case .accommodation: .categoryAccommodation
        case .tourism: .categoryTourism
        case .shopping: .categoryShopping
        case .activity: .categoryActivity
        case .convenience: .categoryConvenience
        case .cafe: .categoryCafe
        case .food: .categoryFood
        }
    }

    /// 저장한 장소 핀에 쓰는 카테고리별 에셋.
    ///
    /// 지도는 `UIImage` 를 받는다. DesignSystem 의 `Image.pin*` 은 `SwiftUI.Image` 라 쓰지 못해,
    /// 생성된 에셋 타입에서 `UIImage` 를 바로 꺼낸다.
    var pin: UIImage {
        switch self {
        case .food: SharedDesignSystemAsset.Pin.food.image
        case .cafe: SharedDesignSystemAsset.Pin.cafe.image
        case .activity: SharedDesignSystemAsset.Pin.activity.image
        case .shopping: SharedDesignSystemAsset.Pin.shopping.image
        case .accommodation: SharedDesignSystemAsset.Pin.accommodation.image
        case .tourism: SharedDesignSystemAsset.Pin.tourism.image
        case .convenience: SharedDesignSystemAsset.Pin.convenience.image
        }
    }

    // 서버 categoryName(한글) 을 카테고리로 매핑
    init(categoryName: String) {
        switch categoryName {
        case "카페": self = .cafe
        case "관광": self = .tourism
        case "놀거리": self = .activity
        case "쇼핑": self = .shopping
        case "숙박": self = .accommodation
        case "편의", "생활 편의": self = .convenience
        default: self = .food
        }
    }
}

public extension PlaceCategory {
    /// 지도 위 칩과 시트 드롭다운이 함께 쓰는 차례. 시안 `a08` 의 칩 차례 그대로다.
    static let mapDisplayOrder: [PlaceCategory] = [
        .food,
        .cafe,
        .activity,
        .shopping,
        .convenience,
        .tourism,
        .accommodation,
    ]

    var displayName: String {
        switch self {
        case .food: "맛집"
        case .cafe: "카페"
        case .activity: "놀거리"
        case .shopping: "쇼핑"
        case .accommodation: "숙박"
        case .tourism: "관광"
        case .convenience: "생활편의"
        }
    }

    /// `AppDropdown` 이 문자열만 주고받아 되돌리는 길이 필요하다.
    static func fromDisplayName(_ name: String) -> PlaceCategory? {
        mapDisplayOrder.first { $0.displayName == name }
    }

    /// 카테고리 드롭다운에서 특정 카테고리가 아니라 전부를 뜻하는 문구.
    static let unfilteredName = "전체"
}
