//
//  ContentSort.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// 게시물 정렬 기준. 미등록 사용자는 popular, datePreference 를 등록한 사용자는 preference
public enum ContentSort: String, Equatable, Sendable {
    case popular = "POPULAR"
    case preference = "PREFERENCE"
}
