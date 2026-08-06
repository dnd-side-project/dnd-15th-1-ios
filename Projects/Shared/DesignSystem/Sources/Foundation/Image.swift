//
//  Image.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import SwiftUI

private typealias Asset = SharedDesignSystemAsset

// MARK: - Icons

// 사용법: Image.heart.resizable().frame(width: 24, height: 24)
public extension Image {
    static var alarm: Image { Asset.alarm.swiftUIImage }
    static var arrow2: Image { Asset.arrow2.swiftUIImage }
    static var arrowDown: Image { Asset.arrowDown.swiftUIImage }
    static var arrowLeft: Image { Asset.arrowLeft.swiftUIImage }
    static var arrowRight: Image { Asset.arrowRight.swiftUIImage }
    static var arrowUp: Image { Asset.arrowUp.swiftUIImage }
    static var bookmarkFill: Image { Asset.bookmarkFill.swiftUIImage }
    static var bookmarkFillColor: Image { Asset.bookmarkFillColor.swiftUIImage }
    static var bookmarkStroke: Image { Asset.bookmarkStroke.swiftUIImage }
    static var calender: Image { Asset.calender.swiftUIImage }
    static var cancel: Image { Asset.cancel.swiftUIImage }
    static var check: Image { Asset.check.swiftUIImage }
    static var checkFalse: Image { Asset.checkFalse.swiftUIImage }
    static var checkTrue: Image { Asset.checkTrue.swiftUIImage }
    static var clock: Image { Asset.clock.swiftUIImage }
    static var dateCalender: Image { Asset.dateCalender.swiftUIImage }
    static var edit: Image { Asset.edit.swiftUIImage }
    static var error: Image { Asset.error.swiftUIImage }
    static var explore: Image { Asset.explore.swiftUIImage }
    static var heart: Image { Asset.heart.swiftUIImage }
    static var home: Image { Asset.home.swiftUIImage }
    static var insta: Image { Asset.insta.swiftUIImage }
    static var locate: Image { Asset.locate.swiftUIImage }
    static var map: Image { Asset.map.swiftUIImage }
    static var mappin: Image { Asset.mappin.swiftUIImage }
    static var menu: Image { Asset.menu.swiftUIImage }
    static var move: Image { Asset.move.swiftUIImage }
    static var my: Image { Asset.my.swiftUIImage }
    static var null: Image { Asset.null.swiftUIImage }
    static var plus: Image { Asset.plus.swiftUIImage }
    static var search: Image { Asset.search.swiftUIImage }
    static var setting: Image { Asset.setting.swiftUIImage }
    static var trash: Image { Asset.trash.swiftUIImage }
    static var walk: Image { Asset.walk.swiftUIImage }
    static var x: Image { Asset.x.swiftUIImage }
}

// MARK: - Category

public extension Image {
    static var categoryAccommodation: Image { Asset.Category.accommodation.swiftUIImage }
    static var categoryActivity: Image { Asset.Category.activity.swiftUIImage }
    static var categoryCafe: Image { Asset.Category.cafe.swiftUIImage }
    static var categoryConvenience: Image { Asset.Category.convenience.swiftUIImage }
    static var categoryFood: Image { Asset.Category.food.swiftUIImage }
    static var categoryShopping: Image { Asset.Category.shopping.swiftUIImage }
    static var categoryTourism: Image { Asset.Category.tourism.swiftUIImage }
}

// MARK: - Pin

public extension Image {
    static var pinAccommodation: Image { Asset.Pin.accommodation.swiftUIImage }
    static var pinActivity: Image { Asset.Pin.activity.swiftUIImage }
    static var pinCafe: Image { Asset.Pin.cafe.swiftUIImage }
    static var pinConvenience: Image { Asset.Pin.convenience.swiftUIImage }
    static var pinFood: Image { Asset.Pin.food.swiftUIImage }
    static var pinShopping: Image { Asset.Pin.shopping.swiftUIImage }
    static var pinTourism: Image { Asset.Pin.tourism.swiftUIImage }
}
