import SwiftUI

/// App intro 한 단계의 표시 콘텐츠.
/// title / image 는 외부에서 주입한다.
public struct AppIntroPage {
    public let title: String
    public let image: Image

    public init(title: String, image: Image) {
        self.title = title
        self.image = image
    }
}
