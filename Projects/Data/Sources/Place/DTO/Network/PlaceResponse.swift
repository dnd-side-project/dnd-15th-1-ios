//
//  PlaceResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

struct SavedPlaceResponseDTO: Decodable, Sendable {
    let memberId: Int
    let placeId: Int
    let name: String
    let address: String
    let roadAddress: String
    let latitude: Double
    let longitude: Double
    let category: String
    let categoryName: String
    let ownershipStatus: String
    let alias: String?
    let savedAt: String
    let thumbnailUrl: String?
    let imageUrls: [String]
}
