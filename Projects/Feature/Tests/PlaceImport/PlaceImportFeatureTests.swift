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
        let response = PlaceImport.fixture(progress: .completed(saved))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
            $0.selectedIDs = ["1", "2", "3", "4"]
        }
        await store.finish()

        XCTAssertEqual(store.state.candidates.map(\.id), ["1", "2", "3", "4"])
    }

    func test_완료인데_후보가없으면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(progress: .completed([])))

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .failed
        }
    }

    func test_검토필요는_후보가없어도_실패화면이_아니다() async throws {
        let response = PlaceImport.fixture(progress: .reviewRequired([]))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
        }
        await store.finish()

        XCTAssertEqual(store.state.candidates, [])
    }

    func test_실패면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(progress: .failed))

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .failed
        }
    }

    func test_일부만저장됐어도_넷다체크된다() async throws {
        let candidates = [
            ImportCandidate.fixture(id: "1", isSaved: true),
            ImportCandidate.fixture(id: "2", isSaved: false),
            ImportCandidate.fixture(id: "3", isSaved: true),
            ImportCandidate.fixture(id: "4", isSaved: false),
        ]
        let response = PlaceImport.fixture(progress: .completed(candidates))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
            $0.selectedIDs = ["1", "2", "3", "4"]
        }
        await store.finish()
    }

    func test_체크를다끄면_버튼문구가_닫기다() async throws {
        let saved = (1...4).map { ImportCandidate.fixture(id: "\($0)", isSaved: true) }
        let response = PlaceImport.fixture(progress: .completed(saved))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
            $0.selectedIDs = ["1", "2", "3", "4"]
        }

        await store.send(.candidateToggled("1")) {
            $0.selectedIDs = ["2", "3", "4"]
        }
        await store.send(.candidateToggled("2")) {
            $0.selectedIDs = ["3", "4"]
        }
        await store.send(.candidateToggled("3")) {
            $0.selectedIDs = ["4"]
        }
        await store.send(.candidateToggled("4")) {
            $0.selectedIDs = []
        }
        await store.finish()

        XCTAssertEqual(store.state.saveButtonTitle, "닫기")
    }

    func test_후보가전부체크되면_버튼문구가_모두저장이다() async throws {
        let fresh = (1...3).map { ImportCandidate.fixture(id: "\($0)", isSaved: false) }
        let response = PlaceImport.fixture(progress: .reviewRequired(fresh))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
            $0.selectedIDs = ["1", "2", "3"]
        }

        XCTAssertEqual(store.state.saveButtonTitle, "모두 저장")

        await store.send(.candidateToggled("1")) {
            $0.selectedIDs = ["2", "3"]
        }
        await store.finish()

        XCTAssertEqual(store.state.saveButtonTitle, "2곳만 저장")
    }

    func test_처리중이면_폴링을이어간다() async throws {
        // 첫 응답은 처리 중, 두 번째는 완료
        let first = PlaceImport.fixture(progress: .processing(retryAfterSeconds: 1))
        let second = PlaceImport.fixture(
            progress: .completed([ImportCandidate.fixture(id: "1", isSaved: false)])
        )
        let store = try makeStore(startResponse: first, pollResponse: second)

        await store.send(.onAppear) {
            $0.started = true
        }
        // 처리 중에는 번호만 받고 로딩 화면에 머문다
        await store.receive(\.importUpdated) {
            $0.importID = "270"
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.importUpdated) {
            $0.phase = .loaded(second)
            $0.selectedIDs = ["1"]
        }
        await store.finish()

        XCTAssertEqual(store.state.candidates.map(\.id), ["1"])
    }

    func test_확인_못_한_후보는_목록과_선택에서_뺀다() async throws {
        let verified = ImportCandidate.fixture(id: "1")
        let unverified = ImportCandidate(
            id: "2",
            extractedName: "확인 못 한 곳",
            extractedAddressHint: "서울 성동구",
            place: nil
        )
        let response = PlaceImport.fixture(progress: .reviewRequired([verified, unverified]))
        let store = try makeStore(response: response)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .loaded(response)
            $0.selectedIDs = ["1"]
        }
        await store.finish()

        XCTAssertEqual(store.state.candidates.map(\.id), ["1"])
        XCTAssertTrue(store.state.isAllSelected)
    }

    func test_확인한_후보가_하나도_없으면_완료여도_실패다() async throws {
        let unverified = ImportCandidate(
            id: "1",
            extractedName: "확인 못 한 곳",
            extractedAddressHint: nil,
            place: nil
        )
        let store = try makeStore(response: .fixture(progress: .completed([unverified])))

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
            $0.phase = .failed
        }
    }

    func test_처리중이_길어져도_실패로_끊지_않는다() async throws {
        let waiting = PlaceImport.fixture(progress: .processing(retryAfterSeconds: 1))
        let store = try makeStore(response: waiting)

        await store.send(.onAppear) {
            $0.started = true
        }
        await store.receive(\.importUpdated) {
            $0.importID = "270"
        }

        // 예전엔 일곱 번째에서 실패로 끊었다
        for _ in 1...10 {
            await clock.advance(by: .seconds(1))
            await store.receive(\.importUpdated)
            XCTAssertEqual(store.state.phase, .loading)
        }

        // 응답이 계속 처리 중이라 폴링이 끝나지 않는다. 남은 대기는 건너뛴다
        await store.skipInFlightEffects()
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
        return TestStore(initialState: PlaceImportFeature.State(link: link)) {
            PlaceImportFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeImportClient.start = { _ in startResponse }
            $0.placeImportClient.poll = { _ in pollResponse }
        }
    }
}

// MARK: - 저장

extension PlaceImportFeatureTests {
    func test_저장을_누르면_고른_후보를_확정하고_저장됨을_위로_올린다() async throws {
        let requests = LockIsolated<[ConfirmRequest]>([])
        let state = try makeLoadedState(importID: "270")
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.placeImportClient.confirm = { importID, candidateIDs in
                requests.withValue {
                    $0.append(ConfirmRequest(importID: importID, candidateIDs: candidateIDs))
                }
            }
            $0.authClient.currentSession = {
                AuthSession(accessToken: "a", refreshToken: "r", userID: "user-42")
            }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveTapped)
        await store.receive(.confirmed(.success(true)))
        await store.receive(.delegate(.placesSaved))
        await store.finish()

        XCTAssertEqual(requests.value, [ConfirmRequest(importID: "270", candidateIDs: ["1"])])
    }

    func test_저장이_실패하면_닫지_않고_그대로_둔다() async throws {
        let state = try makeLoadedState(importID: "270")
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.placeImportClient.confirm = { _, _ in throw PlaceImportError.network }
        }

        await store.send(.saveTapped)
        await store.receive(.confirmed(.failure(.network)))
        await store.finish()
    }

    func test_가져오기_번호가_없으면_저장을_눌러도_아무_일이_없다() async throws {
        let state = try makeLoadedState(importID: nil)
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        }

        await store.send(.saveTapped)
        await store.finish()
    }

    /// 후보 하나가 떠 있고 체크된 상태. 가져오기 번호는 넘긴 값 그대로 넣는다
    private func makeLoadedState(importID: String?) throws -> PlaceImportFeature.State {
        let link = try XCTUnwrap(URL(string: "https://www.instagram.com/reel/example/"))
        let placeImport = PlaceImport.fixture(progress: .reviewRequired([.fixture(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = importID
        return state
    }
}

@MainActor
final class PlaceImportAnalyticsTests: XCTestCase {
    private let clock = TestClock()

    private var link: URL {
        guard let url = URL(string: "https://www.instagram.com/reel/example/") else {
            XCTFail("링크 URL 이 잘못됐다")
            return URL(fileURLWithPath: "/")
        }
        return url
    }

    func test_장소_후보가_나오면_모달_이벤트를_보낸다() async {
        let analytics = AnalyticsRecorder()
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        let store = TestStore(
            initialState: PlaceImportFeature.State(link: link)
        ) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

        await store.send(.importUpdated(.success(placeImport)))
        await store.finish()
        XCTAssertEqual(analytics.events, [.placeSaveModalViewed])
    }

    func test_분석_실패_갈래에서는_모달_이벤트를_안_보낸다() async {
        let analytics = AnalyticsRecorder()
        let placeImport = makeImport(progress: .failed)
        let store = TestStore(
            initialState: PlaceImportFeature.State(link: link)
        ) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

        await store.send(.importUpdated(.success(placeImport)))
        await store.finish()
        XCTAssertEqual(analytics.events, [])
    }

    func test_분석_대기_갈래에서는_모달_이벤트를_안_보낸다() async {
        let analytics = AnalyticsRecorder()
        let waiting = makeImport(progress: .processing(retryAfterSeconds: 1))
        let failed = makeImport(progress: .failed)
        let store = TestStore(initialState: PlaceImportFeature.State(link: link)) {
            PlaceImportFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeImportClient.poll = { _ in failed }
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

        await store.send(.importUpdated(.success(waiting)))
        await clock.advance(by: .seconds(1))
        await store.finish()
        XCTAssertEqual(analytics.events, [])
    }

    func test_저장하면_공유_경로로_시작과_완료_이벤트를_보낸다() async {
        let analytics = AnalyticsRecorder()
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = placeImport.id
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient = analytics.client
            $0.authClient.currentSession = {
                AuthSession(accessToken: "a", refreshToken: "r", userID: "user-42")
            }
            $0.placeImportClient.confirm = { _, _ in }
            $0.dismiss = DismissEffect { }
        }
        store.exhaustivity = .off

        await store.send(.saveTapped)
        await store.finish()
        XCTAssertEqual(
            analytics.events,
            [
                .placeSaveStarted(saveSource: .share),
                .placeSaveCompleted(saveSource: .share, userID: "user-42"),
            ]
        )
    }

    func test_저장이_서버에서_실패하면_완료_이벤트를_안_보낸다() async {
        let analytics = AnalyticsRecorder()
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        var state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        state.importID = placeImport.id
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient = analytics.client
            $0.placeImportClient.confirm = { _, _ in throw PlaceImportError.network }
        }
        store.exhaustivity = .off

        await store.send(.saveTapped)
        await store.finish()
        XCTAssertEqual(analytics.events, [.placeSaveStarted(saveSource: .share)])
    }

    func test_가져오기_번호가_없으면_시작_이벤트를_안_보낸다() async {
        let analytics = AnalyticsRecorder()
        let placeImport = makeImport(progress: .reviewRequired([makeCandidate(id: "1")]))
        let state = PlaceImportFeature.State(link: link, phase: .loaded(placeImport), selectedIDs: ["1"])
        let store = TestStore(initialState: state) {
            PlaceImportFeature()
        } withDependencies: {
            $0.analyticsClient = analytics.client
        }
        store.exhaustivity = .off

        await store.send(.saveTapped)
        await store.finish()
        XCTAssertEqual(analytics.events, [])
    }
}

/// 저장 확정 요청에 실린 값
private struct ConfirmRequest: Equatable, Sendable {
    let importID: String
    let candidateIDs: [String]
}

private func makeCandidate(id: String) -> ImportCandidate {
    .fixture(id: id)
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
