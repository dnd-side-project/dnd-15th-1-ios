//
//  PlaceCategory+Extension.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

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
