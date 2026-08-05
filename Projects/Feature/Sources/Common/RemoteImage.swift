import SwiftUI
import ThirdPartyUI

public struct RemoteImage: View {
    private let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public var body: some View {
        if let url {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    Color.gray.opacity(0.2)
                } else {
                    ProgressView()
                }
            }
        } else {
            Color.gray.opacity(0.1)
        }
    }
}
