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
}
