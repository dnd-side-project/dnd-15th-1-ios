//
//  Place.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation
import SharedUtils

public struct Place: Equatable, Identifiable, Sendable {
    /// 화면이 장소를 가리키는 값. 장소 번호 → 카카오 번호 → 이름·좌표 순서로 만든다.
    /// 저장하지 않고 계산해 같은 값을 두 번 담지 않는다. 응답이 달라도 같은 장소면 같은 값이 나온다
    public var id: String {
        placeID ?? kakaoPlaceID ?? "\(name)|\(coordinate.latitude)|\(coordinate.longitude)"
    }
    /// 둘픽 공용 장소 목록의 번호. 그 목록에 있을 때만 있다. 삭제·상세·별칭이 이 값을 쓴다
    public let placeID: String?
    /// 저장 API(`POST /places`) 가 요구하는 Kakao 장소 ID. 지도 앱 주소도 이 값으로 만든다.
    /// 상세 응답만 반드시 준다. 저장 목록·검색·게시글 응답은 빠질 수 있고,
    /// 코스 장소와 코스 후보 응답은 아예 주지 않는다. 없으면 저장을 부르지 않는다.
    public let kakaoPlaceID: String?
    public let name: String
    public let category: PlaceCategory
    /// 지번 주소
    public let address: String
    /// 도로명 주소. 없는 장소가 있다
    public let roadAddress: String?
    public let coordinate: Coordinate
    /// 저장한 사람 수. 이 값을 주는 응답에서 온 장소만 있다
    public let bookmarkCount: Int?
    /// 대표 사진이 맨 앞이다
    public let thumbnailURLs: [URL]

    public init(
        placeID: String?,
        kakaoPlaceID: String?,
        name: String,
        category: PlaceCategory,
        address: String,
        roadAddress: String?,
        coordinate: Coordinate,
        bookmarkCount: Int?,
        thumbnailURLs: [URL]
    ) {
        self.placeID = placeID
        self.kakaoPlaceID = kakaoPlaceID
        self.name = name
        self.category = category
        self.address = address
        self.roadAddress = roadAddress
        self.coordinate = coordinate
        self.bookmarkCount = bookmarkCount
        self.thumbnailURLs = thumbnailURLs
    }
}
