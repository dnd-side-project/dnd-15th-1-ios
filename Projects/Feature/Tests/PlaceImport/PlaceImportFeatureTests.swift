import ComposableArchitecture
import Domain
@testable import Feature
import Foundation
import XCTest

@MainActor
final class PlaceImportFeatureTests: XCTestCase {
    private let clock = TestClock()

    func test_재공유_이미저장된후보넷_목록이뜨고_넷다체크된다() async throws {
        let saved = (1...4).map { ImportCandidate.fixture(id: "\($0)", isSaved: true) }
        let store = try makeStore(response: .fixture(progress: .completed(saved)))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.candidates.map(\.id), ["1", "2", "3", "4"])
        XCTAssertEqual(store.state.selectedIDs, ["1", "2", "3", "4"])
    }

    func test_완료인데_후보가없으면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(progress: .completed([])))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .failed)
    }

    func test_검토필요는_후보가없어도_실패화면이_아니다() async throws {
        let store = try makeStore(response: .fixture(progress: .reviewRequired([])))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertNotEqual(store.state.phase, .failed)
    }

    func test_실패면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(progress: .failed))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .failed)
    }

    func test_일부만저장됐어도_넷다체크된다() async throws {
        let candidates = [
            ImportCandidate.fixture(id: "1", isSaved: true),
            ImportCandidate.fixture(id: "2", isSaved: false),
            ImportCandidate.fixture(id: "3", isSaved: true),
            ImportCandidate.fixture(id: "4", isSaved: false),
        ]
        let store = try makeStore(response: .fixture(progress: .completed(candidates)))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.selectedIDs, ["1", "2", "3", "4"])
    }

    func test_체크를다끄면_버튼문구가_닫기다() async throws {
        let saved = (1...4).map { ImportCandidate.fixture(id: "\($0)", isSaved: true) }
        let store = try makeStore(response: .fixture(progress: .completed(saved)))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        await store.send(.candidateToggled("1"))
        await store.send(.candidateToggled("2"))
        await store.send(.candidateToggled("3"))
        await store.send(.candidateToggled("4"))

        XCTAssertEqual(store.state.saveButtonTitle, "닫기")
    }

    func test_후보가전부체크되면_버튼문구가_모두저장이다() async throws {
        let fresh = (1...3).map { ImportCandidate.fixture(id: "\($0)", isSaved: false) }
        let store = try makeStore(response: .fixture(progress: .reviewRequired(fresh)))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.saveButtonTitle, "모두 저장")

        await store.send(.candidateToggled("1"))

        XCTAssertEqual(store.state.saveButtonTitle, "2곳만 저장")
    }

    func test_처리중이면_폴링을이어간다() async throws {
        // 첫 응답은 처리 중, 두 번째는 완료. 같은 응답이면 최대 7번까지 폴링한다
        let first = PlaceImport.fixture(progress: .processing(retryAfterSeconds: 1))
        let second = PlaceImport.fixture(
            progress: .completed([ImportCandidate.fixture(id: "1", isSaved: false)])
        )
        let store = try makeStore(startResponse: first, pollResponse: second)

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .loading)
        XCTAssertEqual(store.state.pollCount, 1)

        await clock.advance(by: .seconds(1))
        await store.receive(\.importUpdated)

        XCTAssertNotEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.pollCount, 1)
        XCTAssertEqual(store.state.candidates.map(\.id), ["1"])
    }

    private func makeStore(
        response: PlaceImport
    ) throws -> TestStore<PlaceImportFeature.State, PlaceImportFeature.Action> {
        try makeStore(startResponse: response, pollResponse: response)
    }

    private func makeStore(
        startResponse: PlaceImport,
        pollResponse: PlaceImport
    ) throws -> TestStore<PlaceImportFeature.State, PlaceImportFeature.Action> {
        let link = try XCTUnwrap(URL(string: "https://www.instagram.com/reel/example/"))
        let store = TestStore(initialState: PlaceImportFeature.State(link: link)) {
            PlaceImportFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeImportClient.start = { _ in startResponse }
            $0.placeImportClient.poll = { _ in pollResponse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}

@MainActor
final class PlaceImportAnalyticsTests: XCTestCase {
    private var link: URL {
        guard let url = URL(string: "https://www.instagram.com/reel/example/") else {
            XCTFail("링크 URL 이 잘못됐다")
            return URL(fileURLWithPath: "/")
        }
        return url
    }

    func test_장소_후보가_나오면_모달_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        let store = TestStore(
            initialState: PlaceImportFeature.State(link: link)
        ) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.importUpdated(.success(placeImport))) {
            $0.importID = placeImport.id
            $0.phase = .loaded(placeImport)
            $0.selectedIDs = ["1"]
        }
        await store.finish()
        XCTAssertEqual(sent.value, [.placeSaveModalViewed])
    }

    func test_분석_실패_갈래에서는_모달_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .failed)
        let store = TestStore(
            initialState: PlaceImportFeature.State(link: link)
        ) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.importUpdated(.success(placeImport))) {
            $0.importID = placeImport.id
            $0.phase = .failed
        }
        await store.finish()
        XCTAssertTrue(sent.value.isEmpty)
    }

    func test_분석_대기_갈래에서는_모달_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        var state = PlaceImportFeature.State(link: link)
        state.pollCount = 7
        let placeImport = makeImport(progress: .processing(retryAfterSeconds: 1))
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.importUpdated(.success(placeImport))) {
            $0.importID = placeImport.id
            $0.phase = .failed
        }
        await store.finish()
        XCTAssertTrue(sent.value.isEmpty)
    }

    func test_저장_버튼을_누르면_공유_경로로_시작_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = placeImport.id
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
            $0.authClient.currentSession = {
                AuthSession(accessToken: "a", refreshToken: "r", userID: "user-42")
            }
            $0.placeImportClient.confirm = { _, _ in }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveTapped)
        await store.receive(.confirmed(.success(true)))
        await store.receive(.delegate(.placesSaved))
        await store.finish()
        XCTAssertEqual(
            sent.value,
            [
                .placeSaveStarted(saveSource: .share),
                .placeSaveCompleted(saveSource: .share, userID: "user-42"),
            ]
        )
    }

    func test_공유_저장이_성공하면_완료_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = placeImport.id
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
            $0.authClient.currentSession = {
                AuthSession(accessToken: "a", refreshToken: "r", userID: "user-42")
            }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.confirmed(.success(true)))
        await store.receive(.delegate(.placesSaved))
        await store.finish()
        XCTAssertEqual(sent.value, [.placeSaveCompleted(saveSource: .share, userID: "user-42")])
    }

    func test_저장이_서버에서_실패하면_완료_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = placeImport.id
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
            $0.placeImportClient.confirm = { _, _ in throw PlaceImportError.network }
        }

        await store.send(.saveTapped)
        await store.receive(.confirmed(.failure(.network)))
        await store.finish()
        XCTAssertEqual(sent.value, [.placeSaveStarted(saveSource: .share)])
    }

    func test_가져오기_번호가_없으면_시작_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        let state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.saveTapped)
        await store.finish()
        XCTAssertTrue(sent.value.isEmpty)
    }
}

private func makeCandidate(id: String) -> ImportCandidate {
    ImportCandidate(
        id: id,
        extractedName: "후보 \(id)",
        extractedAddressHint: nil,
        place: nil
    )
}

private func makeImport(progress: ImportProgress) -> PlaceImport {
    PlaceImport(
        id: "9",
        canonicalURL: URL(string: "https://www.instagram.com/reel/example/"),
        progress: progress,
        content: ImportContent(
            title: "제목",
            caption: nil,
            thumbnailURL: nil,
            author: nil,
            publishedOn: nil
        )
    )
}
