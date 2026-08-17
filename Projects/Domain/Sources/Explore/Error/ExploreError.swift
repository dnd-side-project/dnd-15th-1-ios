//
//  ExploreError.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

public enum ExploreError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case notFound
    case unknown
}
