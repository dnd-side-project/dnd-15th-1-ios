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
    static var calendar: Image { Asset.calendar.swiftUIImage }
    static var cancel: Image { Asset.cancel.swiftUIImage }
    static var check: Image { Asset.check.swiftUIImage }
    static var checkFalse: Image { Asset.checkFalse.swiftUIImage }
    static var checkTrue: Image { Asset.checkTrue.swiftUIImage }
    static var clock: Image { Asset.clock.swiftUIImage }
    static var dateCalendar: Image { Asset.dateCalendar.swiftUIImage }
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
    static var tip: Image { Asset.tip.swiftUIImage }
    static var trash: Image { Asset.trash.swiftUIImage }
    static var walk: Image { Asset.walk.swiftUIImage }
    static var x: Image { Asset.x.swiftUIImage }
}

// MARK: - Social

public extension Image {
    static var socialApple: Image { Asset.Social.apple.swiftUIImage }
    static var socialKakao: Image { Asset.Social.kakao.swiftUIImage }
    static var socialGoogle: Image { Asset.Social.google.swiftUIImage }
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

// MARK: - App Intro

public extension Image {
    static var appIntroShare: Image { Asset.appIntroShare.swiftUIImage }
    static var appIntroSave: Image { Asset.appIntroSave.swiftUIImage }
    static var appIntroPlan: Image { Asset.appIntroPlan.swiftUIImage }
}

// MARK: - Home

public extension Image {
    static var logo: Image { Asset.logo.swiftUIImage }
    static var bannerCoupleConnect: Image { Asset.bannerCoupleConnect.swiftUIImage }
    static var bannerPeek: Image { Asset.bannerPeek.swiftUIImage }
    static var bannerCalendar: Image { Asset.bannerCalendar.swiftUIImage }
    static var placeEmpty: Image { Asset.placeEmpty.swiftUIImage }
}

// MARK: - Couple Connect

public extension Image {
    static var coupleConnectBefore: Image { Asset.coupleConnectBefore.swiftUIImage }
    static var coupleConnectComplete: Image { Asset.coupleConnectComplete.swiftUIImage }
    static var coupleConnectModal: Image { Asset.coupleConnectModal.swiftUIImage }
}

// MARK: - DateType

public extension Image {
    static var dateTypeActive: Image { Asset.DateType.active.swiftUIImage }
    static var dateTypeDay: Image { Asset.DateType.day.swiftUIImage }
    static var dateTypeFood: Image { Asset.DateType.food.swiftUIImage }
    static var dateTypeIndoor: Image { Asset.DateType.indoor.swiftUIImage }
    static var dateTypeNight: Image { Asset.DateType.night.swiftUIImage }
    static var dateTypeOutdoor: Image { Asset.DateType.outdoor.swiftUIImage }
    static var dateTypeSightseeing: Image { Asset.DateType.sightseeing.swiftUIImage }
    static var dateTypeStatic: Image { Asset.DateType.`static`.swiftUIImage }
    static var dateTypeGraphic: Image { Asset.dateTypeGraphic.swiftUIImage }
}
