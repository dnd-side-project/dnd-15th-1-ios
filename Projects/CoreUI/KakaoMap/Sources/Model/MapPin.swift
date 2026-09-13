import CoreGraphics
import SharedUtils
import UIKit

/// 핀 하나를 어떻게 그릴지.
///
/// 같은 스타일 식별자를 쓰는 핀은 이 값을 공유한다. SDK 에 한 번만 등록한다
public struct MapPinStyle {
    public let image: UIImage
    /// 그림의 어느 점이 좌표에 놓이는지. `(0.5, 0.5)` 면 그림 한가운데다
    public let anchorPoint: CGPoint

    public init(image: UIImage, anchorPoint: CGPoint) {
        self.image = image
        self.anchorPoint = anchorPoint
    }
}

/// 지도에 찍는 핀 하나.
///
/// 이 모듈은 핀이 무엇을 뜻하는지 모른다. 장소인지 코스 번호인지는 화면 층이 안다
public struct MapPin: Identifiable {
    public let id: String
    public let coordinate: Coordinate
    /// 같은 값이면 같은 그림·기준점을 쓴다는 약속이다. 이 모듈은 문자열의 뜻을 모른다
    public let styleID: String
    /// 겹쳐 그릴 때의 순서. 큰 쪽이 위다
    public let rank: Int
    /// 스타일 식별자를 처음 볼 때 한 번만 부른다.
    ///
    /// 핀마다 그림을 미리 만들어 두지 않는 이유는 그림 만들기가 비싸기 때문이다.
    /// 화면이 다시 그릴 때마다 핀 배열은 새로 생기지만 그림은 그대로 쓴다
    public let makeStyle: () -> MapPinStyle

    public init(
        id: String,
        coordinate: Coordinate,
        styleID: String,
        rank: Int,
        makeStyle: @escaping () -> MapPinStyle
    ) {
        self.id = id
        self.coordinate = coordinate
        self.styleID = styleID
        self.rank = rank
        self.makeStyle = makeStyle
    }
}

extension MapPin: Equatable {
    /// `makeStyle` 은 비교에서 뺀다. 함수는 비교할 수 없고,
    /// 같은 스타일 식별자면 같은 그림이라는 약속이 그 자리를 대신한다
    public static func == (lhs: MapPin, rhs: MapPin) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate == rhs.coordinate
            && lhs.styleID == rhs.styleID
            && lhs.rank == rhs.rank
    }
}
