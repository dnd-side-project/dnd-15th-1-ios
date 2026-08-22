//
//  PlaceRequest.swift
//  Dulpick
//
//  Created by 이인호 on 8/22/26.
//

import Foundation

// POST /api/v1/places 본문. 카카오 식별자·검색어·별칭
struct PlaceSaveRequestDTO: Encodable, Sendable {
    let kakaoPlaceId: String
    let query: String
    let alias: String?
}
