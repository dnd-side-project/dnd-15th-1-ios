//
//  SavedPlace.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Foundation

public struct SavedPlace: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PlaceCategory

    public init(
        id: String,
        name: String,
        category: PlaceCategory
    ) {
        self.id = id
        self.name = name
        self.category = category
    }
}
