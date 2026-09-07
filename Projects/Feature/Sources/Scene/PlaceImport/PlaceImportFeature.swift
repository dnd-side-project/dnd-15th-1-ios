//
//  PlaceImportFeature.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Domain
import Foundation
import ThirdParty

@Reducer
public struct PlaceImportFeature {
    @ObservableState
    public struct State: Equatable {
        // 공유로 받은 인스타 링크. API 요청에 사용
        public var link: URL
        public var phase: Phase
        public var selectedIDs: Set<Int>
        var importId: Int?
        var started = false
        var pollCount = 0

        public enum Phase: Equatable {
            case loading
            case loaded(PlaceImport)
            case failed
        }

        public var candidates: [ImportCandidate] {
            if case let .loaded(placeImport) = phase {
                return placeImport.candidates
            }
            return []
        }

        public var isAllSelected: Bool {
            !candidates.isEmpty && selectedIDs.count == candidates.count
        }

        public var saveButtonTitle: String {
            if selectedIDs.isEmpty {
                return "닫기"
            }
            return isAllSelected ? "모두 저장" : "\(selectedIDs.count)곳만 저장"
        }

        public init(link: URL, phase: Phase = .loading, selectedIDs: Set<Int> = []) {
            self.link = link
            self.phase = phase
            self.selectedIDs = selectedIDs
        }
    }

    public enum Action: Equatable {
        case onAppear
        case importUpdated(Result<PlaceImport, PlaceImportError>)
        case candidateToggled(Int)
        case saveTapped
        case confirmed(Result<Bool, PlaceImportError>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            // 장소 저장 완료. 상위가 홈 데이터를 갱신하게 한다
            case placesSaved
        }
    }

    // retryAfterSeconds 가 없을 때 쓰는 기본 폴링 간격
    private let fallbackDelay = 2
    private let maxPollCount = 7

    @Dependency(\.placeImportClient) var placeImportClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            guard !state.started else { return .none }
            state.started = true
            return start(link: state.link)

        case let .importUpdated(.success(placeImport)):
            return applyImport(state: &state, placeImport: placeImport)

        case .importUpdated(.failure):
            state.phase = .failed
            return .none

        case let .candidateToggled(id):
            if state.selectedIDs.contains(id) {
                state.selectedIDs.remove(id)
            } else {
                state.selectedIDs.insert(id)
            }
            return .none

        case .saveTapped:
            return confirmOrDismiss(state: state)

        case .confirmed(.success):
            // 시트를 닫으면 남은 효과가 취소되므로 이벤트를 먼저 보낸다
            return .run { [analyticsClient, authClient, dismiss] send in
                let userID = (try? await authClient.currentSession())?.userID
                await analyticsClient.track(.placeSaveCompleted(saveSource: .share, userID: userID))
                await send(.delegate(.placesSaved))
                await dismiss()
            }

        case .confirmed(.failure):
            return .none

        case .delegate:
            return .none

        case .closeTapped:
            return .run { [dismiss] _ in await dismiss() }
        }
    }

    private func confirmOrDismiss(state: State) -> Effect<Action> {
        // 저장할 것이 없으면 이 버튼은 닫기로 동작한다
        guard !state.selectedIDs.isEmpty else {
            return .run { [dismiss] _ in await dismiss() }
        }
        guard let importId = state.importId else { return .none }
        return .merge(
            .run { [analyticsClient] _ in
                await analyticsClient.track(.placeSaveStarted(saveSource: .share))
            },
            confirm(importId: importId, candidateIDs: Array(state.selectedIDs))
        )
    }

    private func applyImport(state: inout State, placeImport: PlaceImport) -> Effect<Action> {
        state.importId = placeImport.importId

        switch placeImport.nextAction {
        case .wait:
            return waitAndPoll(state: &state, placeImport: placeImport)

        case .selectPlaces:
            return showCandidates(state: &state, placeImport: placeImport, failWhenEmpty: false)

        case .completed:
            return showCandidates(state: &state, placeImport: placeImport, failWhenEmpty: true)

        case .noAction:
            // 서버가 이 값을 언제 주는지 명세에 없다. 작업 상태를 보고 정한다
            switch placeImport.status {
            case .completed:
                return showCandidates(state: &state, placeImport: placeImport, failWhenEmpty: true)
            case .reviewRequired:
                return showCandidates(state: &state, placeImport: placeImport, failWhenEmpty: false)
            case .failed:
                state.phase = .failed
                return .none
            case .received, .processing:
                return waitAndPoll(state: &state, placeImport: placeImport)
            }

        case .retry:
            state.phase = .failed
            return .none
        }
    }

    private func waitAndPoll(state: inout State, placeImport: PlaceImport) -> Effect<Action> {
        guard state.pollCount < maxPollCount else {
            state.phase = .failed
            return .none
        }
        state.pollCount += 1
        let delay = placeImport.retryAfterSeconds
            .flatMap { $0 > 0 ? $0 : nil }
            ?? fallbackDelay
        return poll(importId: placeImport.importId, after: delay)
    }

    private func showCandidates(
        state: inout State,
        placeImport: PlaceImport,
        failWhenEmpty: Bool
    ) -> Effect<Action> {
        if failWhenEmpty, placeImport.candidates.isEmpty {
            state.phase = .failed
            return .none
        }
        state.phase = .loaded(placeImport)
        state.selectedIDs = Set(placeImport.candidates.map(\.candidateId))
        return .run { [analyticsClient] _ in
            await analyticsClient.track(.placeSaveModalViewed)
        }
    }

    private func start(link: URL) -> Effect<Action> {
        .run { [placeImportClient] send in
            do {
                let result = try await placeImportClient.start(sourceUrl: link.absoluteString)
                await send(.importUpdated(.success(result)))
            } catch {
                await send(.importUpdated(.failure(mapError(error))))
            }
        }
    }

    private func poll(importId: Int, after seconds: Int) -> Effect<Action> {
        .run { [placeImportClient] send in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            do {
                let result = try await placeImportClient.poll(importId: importId)
                await send(.importUpdated(.success(result)))
            } catch {
                await send(.importUpdated(.failure(mapError(error))))
            }
        }
    }

    private func confirm(importId: Int, candidateIDs: [Int]) -> Effect<Action> {
        .run { [placeImportClient] send in
            do {
                try await placeImportClient.confirm(importId: importId, candidateIDs: candidateIDs)
                await send(.confirmed(.success(true)))
            } catch {
                await send(.confirmed(.failure(mapError(error))))
            }
        }
    }
}

private func mapError(_ error: Error) -> PlaceImportError {
    error as? PlaceImportError ?? .unknown
}
