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

/// 별칭 수정 요청. alias 가 nil 이어도 키를 반드시 보낸다 —
/// 키가 빠지면 서버가 빈 바디로 보고 별칭을 지운다. 뜻이 같아도 의도를 분명히 한다
struct PlaceAliasUpdateRequestDTO: Encodable, Sendable {
    let alias: String?

    enum CodingKeys: String, CodingKey {
        case alias
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alias, forKey: .alias)
    }
}
