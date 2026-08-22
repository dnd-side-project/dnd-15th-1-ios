import Domain
@testable import Feature
import ThirdParty
import XCTest

@MainActor
final class PostDetailFeatureTests: XCTestCase {
    private let detail = PostDetailContent(
        id: "1",
        title: "제목",
        caption: "본문",
        canonicalURL: URL(string: "https://www.instagram.com/reel/example/"),
        places: [
            PostDetailPlace(id: "101", name: "가게 하나", category: .cafe, isSaved: true,
                            coordinate: Coordinate(latitude: 37.5, longitude: 127.0)),
            PostDetailPlace(id: "102", name: "가게 둘", category: .food, isSaved: false,
                            coordinate: Coordinate(latitude: 37.6, longitude: 127.1)),
        ]
    )

    private func store(
        state: PostDetailFeature.State = PostDetailFeature.State(contentID: "1"),
        detail: PostDetailContent? = nil,
        error: ExploreError? = nil,
        load: (@Sendable (String) async throws -> PostDetailContent)? = nil
    ) -> TestStore<PostDetailFeature.State, PostDetailFeature.Action> {
        let loaded = detail
        let failure = error
        return TestStore(initialState: state) {
            PostDetailFeature()
        } withDependencies: {
            $0.postDetailContentClient.contentDetail = { id in
                if let load { return try await load(id) }
                if let failure { throw failure }
                guard let loaded else { throw ExploreError.unknown }
                return loaded
            }
        }
    }

    func test_onAppear_상세를_받아_상태를_채운다() async {
        let loaded = detail
        let sut = store(detail: loaded)

        await sut.send(.onAppear) {
            $0.isLoading = true
            $0.loadFailed = false
        }
        await sut.receive(\.detailResponse) {
            $0.detail = loaded
            $0.savedPlaceIDs = ["101"]
            $0.isLoading = false
        }
    }

    func test_인증만료면_상위로_올린다() async {
        let sut = store(error: .unauthorized)

        await sut.send(.onAppear) {
            $0.isLoading = true
        }
        await sut.receive(\.detailFailed) {
            $0.isLoading = false
            $0.loadFailed = true
        }
        await sut.receive(\.delegate.sessionExpired)
    }

    func test_없는_게시글이면_화면_안에서_끝낸다() async {
        let sut = store(error: .notFound)

        await sut.send(.onAppear) {
            $0.isLoading = true
        }
        await sut.receive(\.detailFailed) {
            $0.isLoading = false
            $0.loadFailed = true
        }
    }

    func test_다시시도가_한번_더_부른다() async {
        let loaded = detail
        var state = PostDetailFeature.State(contentID: "1")
        state.loadFailed = true
        let sut = store(state: state, detail: loaded)

        await sut.send(.retryTapped) {
            $0.isLoading = true
            $0.loadFailed = false
        }
        await sut.receive(\.detailResponse) {
            $0.detail = loaded
            $0.savedPlaceIDs = ["101"]
            $0.isLoading = false
        }
    }

    func test_더보기가_본문만_펼친다() async {
        let sut = store()

        await sut.send(.expandToggled) {
            $0.isExpanded = true
        }
        await sut.send(.expandToggled) {
            $0.isExpanded = false
        }
    }

    func test_행_북마크는_그_행만_뒤집는다() async {
        var state = PostDetailFeature.State(contentID: "1")
        state.detail = detail
        state.savedPlaceIDs = ["101"]
        let sut = store(state: state)

        await sut.send(.placeBookmarkTapped("102")) {
            $0.savedPlaceIDs = ["101", "102"]
        }
        await sut.send(.placeBookmarkTapped("101")) {
            $0.savedPlaceIDs = ["102"]
        }
    }

    func test_행을_누르면_상위로_올린다() async {
        let sut = store()

        await sut.send(.placeTapped("101"))
        await sut.receive(.delegate(.placeSelected("101")))
    }

    func test_닫기를_누르면_상위로_올린다() async {
        let sut = store()

        await sut.send(.closeTapped)
        await sut.receive(\.delegate.closeRequested)
    }

    func test_부르는중에_온_두번째_onAppear는_아무일도_안한다() async {
        let loaded = detail
        let gate = AsyncStream.makeStream(of: Void.self)
        let sut = store(detail: loaded) { _ in
            for await _ in gate.stream { break }
            return loaded
        }

        await sut.send(.onAppear) {
            $0.isLoading = true
        }
        await sut.send(.onAppear)

        gate.continuation.finish()
        await sut.receive(\.detailResponse) {
            $0.detail = loaded
            $0.savedPlaceIDs = ["101"]
            $0.isLoading = false
        }
    }

    func test_이미_값이_있으면_onAppear가_아무일도_안한다() async {
        var state = PostDetailFeature.State(contentID: "1")
        state.detail = detail
        state.savedPlaceIDs = ["101"]
        let sut = store(state: state, detail: detail)

        await sut.send(.onAppear)
    }
}
