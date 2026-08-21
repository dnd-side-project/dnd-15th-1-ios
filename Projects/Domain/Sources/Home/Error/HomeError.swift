//
//  HomeError.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

public enum HomeError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case unknown
}
