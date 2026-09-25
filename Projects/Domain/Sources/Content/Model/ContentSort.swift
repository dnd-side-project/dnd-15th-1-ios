//
//  ContentSort.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// 게시물 정렬 기준. 미등록 사용자는 popular, datePreference 를 등록한 사용자는 preference.
/// 서버 쿼리 문자열 변환은 Data 가 맡는다
public enum ContentSort: Equatable, Sendable {
    case popular
    case preference
}
