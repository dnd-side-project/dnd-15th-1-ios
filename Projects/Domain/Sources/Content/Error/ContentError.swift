//
//  ContentError.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

public enum ContentError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case notFound
    case unknown
}
