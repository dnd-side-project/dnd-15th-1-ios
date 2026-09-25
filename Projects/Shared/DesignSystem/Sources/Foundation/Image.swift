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
    static var arrowRight: Image { Asset.arrowRight.swiftUIImage }
    static var bookmarkEmpty: Image { Asset.bookmarkEmpty.swiftUIImage }
    static var bookmarkFilled: Image { Asset.bookmarkFilled.swiftUIImage }
    static var bookmarkFilledBlack: Image { Asset.bookmarkFilledBlack.swiftUIImage }
    static var calendar: Image { Asset.calendar.swiftUIImage }
    static var calendarHeart: Image { Asset.calendarHeart.swiftUIImage }
    static var cancel: Image { Asset.cancel.swiftUIImage }
    static var check: Image { Asset.check.swiftUIImage }
    static var checkEmpty: Image { Asset.checkEmpty.swiftUIImage }
    static var checkFilled: Image { Asset.checkFilled.swiftUIImage }
    static var chevronDown: Image { Asset.chevronDown.swiftUIImage }
    static var chevronLeft: Image { Asset.chevronLeft.swiftUIImage }
    static var chevronRight: Image { Asset.chevronRight.swiftUIImage }
    static var chevronUp: Image { Asset.chevronUp.swiftUIImage }
    static var clock: Image { Asset.clock.swiftUIImage }
    static var edit: Image { Asset.edit.swiftUIImage }
    static var error: Image { Asset.error.swiftUIImage }
    static var explore: Image { Asset.explore.swiftUIImage }
    static var heart: Image { Asset.heart.swiftUIImage }
    static var heartBordered: Image { Asset.heartBordered.swiftUIImage }
    static var home: Image { Asset.home.swiftUIImage }
    static var insta: Image { Asset.insta.swiftUIImage }
    static var locate: Image { Asset.locate.swiftUIImage }
    static var map: Image { Asset.map.swiftUIImage }
    static var mapPin: Image { Asset.mapPin.swiftUIImage }
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

// MARK: - Social

public extension Image {
    static var socialApple: Image { Asset.Social.apple.swiftUIImage }
    static var socialGoogle: Image { Asset.Social.google.swiftUIImage }
    static var socialKakao: Image { Asset.Social.kakao.swiftUIImage }
}

// MARK: - Illustration

public extension Image {
    static var illustrationConnect: Image { Asset.illustrationConnect.swiftUIImage }
    static var illustrationConnected: Image { Asset.illustrationConnected.swiftUIImage }
    static var illustrationPlan: Image { Asset.illustrationPlan.swiftUIImage }
    static var illustrationPreference: Image { Asset.illustrationPreference.swiftUIImage }
    static var illustrationSave: Image { Asset.illustrationSave.swiftUIImage }
    static var illustrationShare: Image { Asset.illustrationShare.swiftUIImage }
    static var illustrationTogether: Image { Asset.illustrationTogether.swiftUIImage }
    static var illustrationWelcome: Image { Asset.illustrationWelcome.swiftUIImage }
}

// MARK: - Modal

public extension Image {
    static var modalSave: Image { Asset.modalSave.swiftUIImage }
    static var modalSkip: Image { Asset.modalSkip.swiftUIImage }
    static var modalWarning: Image { Asset.modalWarning.swiftUIImage }
}

// MARK: - Empty

public extension Image {
    static var emptyResult: Image { Asset.emptyResult.swiftUIImage }
    static var emptySchedule: Image { Asset.emptySchedule.swiftUIImage }
}

// MARK: - Banner

public extension Image {
    static var bannerConnect: Image { Asset.bannerConnect.swiftUIImage }
    static var bannerCount: Image { Asset.bannerCount.swiftUIImage }
    static var bannerCourse: Image { Asset.bannerCourse.swiftUIImage }
    static var bannerUpcoming: Image { Asset.bannerUpcoming.swiftUIImage }
}

// MARK: - Background

public extension Image {
    static var backgroundLaunch: Image { Asset.backgroundLaunch.swiftUIImage }
}

// MARK: - Profile

public extension Image {
    static var profileGreen: Image { Asset.profileGreen.swiftUIImage }
    static var profileMint: Image { Asset.profileMint.swiftUIImage }
    static var profilePink: Image { Asset.profilePink.swiftUIImage }
    static var profileWhite: Image { Asset.profileWhite.swiftUIImage }
    static var profileYellow: Image { Asset.profileYellow.swiftUIImage }
}

// MARK: - Logos

public extension Image {
    static var brandLockup: Image { Asset.brandLockup.swiftUIImage }
    static var brandMark: Image { Asset.brandMark.swiftUIImage }
    static var brandWordmark: Image { Asset.brandWordmark.swiftUIImage }
}
