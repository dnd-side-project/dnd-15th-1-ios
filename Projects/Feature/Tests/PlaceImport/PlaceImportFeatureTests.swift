import ComposableArchitecture
import Domain
@testable import Feature
import Foundation
import XCTest

@MainActor
final class PlaceImportFeatureTests: XCTestCase {
    func test_재공유_이미저장된후보넷_목록이뜨고_넷다체크된다() async throws {
        let saved = (1...4).map { ImportCandidate.fixture(candidateId: $0, savedByMe: true) }
        let store = try makeStore(response: .fixture(
            status: .completed,
            nextAction: .completed,
            candidates: saved
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.candidates.map(\.candidateId), [1, 2, 3, 4])
        XCTAssertEqual(store.state.selectedIDs, [1, 2, 3, 4])
    }

    func test_다음동작이없고_작업상태가완료면_목록이뜬다() async throws {
        let saved = [ImportCandidate.fixture(candidateId: 1, savedByMe: true)]
        let store = try makeStore(response: .fixture(
            status: .completed,
            nextAction: .noAction,
            candidates: saved
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.candidates.map(\.candidateId), [1])
    }

    func test_다음동작이없고_작업상태가실패면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(
            status: .failed,
            nextAction: .noAction,
            candidates: []
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .failed)
    }

    func test_완료인데_후보가없으면_실패화면이뜬다() async throws {
        let store = try makeStore(response: .fixture(
            status: .completed,
            nextAction: .completed,
            candidates: []
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .failed)
    }

    func test_일부만저장됐어도_넷다체크된다() async throws {
        let candidates = [
            ImportCandidate.fixture(candidateId: 1, savedByMe: true),
            ImportCandidate.fixture(candidateId: 2, savedByMe: false),
            ImportCandidate.fixture(candidateId: 3, savedByMe: true),
            ImportCandidate.fixture(candidateId: 4, savedByMe: false),
        ]
        let store = try makeStore(response: .fixture(
            status: .completed,
            nextAction: .completed,
            candidates: candidates
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.selectedIDs, [1, 2, 3, 4])
    }

    func test_체크를다끄면_버튼문구가_닫기다() async throws {
        let saved = (1...4).map { ImportCandidate.fixture(candidateId: $0, savedByMe: true) }
        let store = try makeStore(response: .fixture(
            status: .completed,
            nextAction: .completed,
            candidates: saved
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        await store.send(.candidateToggled(1))
        await store.send(.candidateToggled(2))
        await store.send(.candidateToggled(3))
        await store.send(.candidateToggled(4))

        XCTAssertEqual(store.state.saveButtonTitle, "닫기")
    }

    func test_후보가전부체크되면_버튼문구가_모두저장이다() async throws {
        let fresh = (1...3).map { ImportCandidate.fixture(candidateId: $0, savedByMe: false) }
        let store = try makeStore(response: .fixture(
            status: .reviewRequired,
            nextAction: .selectPlaces,
            candidates: fresh
        ))

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.saveButtonTitle, "모두 저장")

        await store.send(.candidateToggled(1))

        XCTAssertEqual(store.state.saveButtonTitle, "2곳만 저장")
    }

    func test_다음동작이없고_작업상태가처리중이면_폴링을이어간다() async throws {
        // 첫 응답은 처리 중, 두 번째는 완료. 같은 응답이면 최대 7번까지 폴링한다
        let first = PlaceImport.fixture(
            status: .processing,
            nextAction: .noAction,
            candidates: [],
            retryAfterSeconds: 1
        )
        let second = PlaceImport.fixture(
            status: .completed,
            nextAction: .completed,
            candidates: [ImportCandidate.fixture(candidateId: 1, savedByMe: false)]
        )
        let store = try makeStore(startResponse: first, pollResponse: second)

        await store.send(.onAppear)
        await store.receive(\.importUpdated)

        XCTAssertEqual(store.state.phase, .loading)
        XCTAssertEqual(store.state.pollCount, 1)

        await store.receive(\.importUpdated)

        XCTAssertNotEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.pollCount, 1)
        XCTAssertEqual(store.state.candidates.map(\.candidateId), [1])
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
            $0.placeImportClient.start = { _ in startResponse }
            $0.placeImportClient.poll = { _ in pollResponse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
