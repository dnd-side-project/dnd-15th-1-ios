//
//  PlaceImport.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Foundation

/// 인스타 게시물에서 장소를 가져오는 작업 하나
public struct PlaceImport: Equatable, Identifiable, Sendable {
    public let id: String
    /// 추적 파라미터를 없앤 원본 게시물 링크. 주소를 못 읽으면 nil 이고, 가져오기는 그대로 계속된다
    public let canonicalURL: URL?
    public let progress: ImportProgress
    public let content: ImportContent

    public init(
        id: String,
        canonicalURL: URL?,
        progress: ImportProgress,
        content: ImportContent
    ) {
        self.id = id
        self.canonicalURL = canonicalURL
        self.progress = progress
        self.content = content
    }
}

/// 가져오기 진행 상태. 서버의 작업 상태와 다음 동작 두 값을 Data 가 이 넷으로 읽는다
public enum ImportProgress: Equatable, Sendable {
    /// 아직 분석 중이다. 다시 물을 때까지 기다릴 초를 서버가 주기도 한다
    case processing(retryAfterSeconds: Int?)
    /// 사용자가 저장할 장소를 고른다
    case reviewRequired([ImportCandidate])
    /// 분석이 끝났다. 후보가 없으면 화면이 실패로 본다
    case completed([ImportCandidate])
    case failed
}
