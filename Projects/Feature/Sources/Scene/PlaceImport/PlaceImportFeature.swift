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
        public var selectedIDs: Set<String>
        var importID: String?
        var started = false
        var pollCount = 0

        public enum Phase: Equatable {
            case loading
            case loaded(PlaceImport)
            case failed
        }

        public var candidates: [ImportCandidate] {
            guard case let .loaded(placeImport) = phase else { return [] }
            switch placeImport.progress {
            case let .reviewRequired(candidates), let .completed(candidates):
                return candidates
            case .processing, .failed:
                return []
            }
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

        public init(link: URL, phase: Phase = .loading, selectedIDs: Set<String> = []) {
            self.link = link
            self.phase = phase
            self.selectedIDs = selectedIDs
        }
    }

    public enum Action: Equatable {
        case onAppear
        case importUpdated(Result<PlaceImport, PlaceImportError>)
        case candidateToggled(String)
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
    @Dependency(\.continuousClock) var clock

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
        guard let importID = state.importID else { return .none }
        return .merge(
            .run { [analyticsClient] _ in
                await analyticsClient.track(.placeSaveStarted(saveSource: .share))
            },
            confirm(importID: importID, candidateIDs: Array(state.selectedIDs))
        )
    }

    // 서버 값 조합의 해석은 Data 매퍼가 맡는다. 여기서는 네 갈래만 본다
    private func applyImport(state: inout State, placeImport: PlaceImport) -> Effect<Action> {
        state.importID = placeImport.id

        switch placeImport.progress {
        case let .processing(retryAfterSeconds):
            return waitAndPoll(
                state: &state,
                importID: placeImport.id,
                retryAfterSeconds: retryAfterSeconds
            )

        case let .reviewRequired(candidates):
            return showCandidates(
                state: &state,
                placeImport: placeImport,
                candidates: candidates,
                failWhenEmpty: false
            )

        case let .completed(candidates):
            return showCandidates(
                state: &state,
                placeImport: placeImport,
                candidates: candidates,
                failWhenEmpty: true
            )

        case .failed:
            state.phase = .failed
            return .none
        }
    }

    private func waitAndPoll(
        state: inout State,
        importID: String,
        retryAfterSeconds: Int?
    ) -> Effect<Action> {
        guard state.pollCount < maxPollCount else {
            state.phase = .failed
            return .none
        }
        state.pollCount += 1
        let delay = retryAfterSeconds
            .flatMap { $0 > 0 ? $0 : nil }
            ?? fallbackDelay
        return poll(importID: importID, after: delay)
    }

    private func showCandidates(
        state: inout State,
        placeImport: PlaceImport,
        candidates: [ImportCandidate],
        failWhenEmpty: Bool
    ) -> Effect<Action> {
        if failWhenEmpty, candidates.isEmpty {
            state.phase = .failed
            return .none
        }
        state.phase = .loaded(placeImport)
        state.selectedIDs = Set(candidates.map(\.id))
        return .run { [analyticsClient] _ in
            await analyticsClient.track(.placeSaveModalViewed)
        }
    }

    private func start(link: URL) -> Effect<Action> {
        .run { [placeImportClient] send in
            do {
                let result = try await placeImportClient.start(sourceURL: link)
                await send(.importUpdated(.success(result)))
            } catch {
                await send(.importUpdated(.failure(mapError(error))))
            }
        }
    }

    private func poll(importID: String, after seconds: Int) -> Effect<Action> {
        .run { [placeImportClient, clock] send in
            do {
                try await clock.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            do {
                let result = try await placeImportClient.poll(importID: importID)
                await send(.importUpdated(.success(result)))
            } catch {
                await send(.importUpdated(.failure(mapError(error))))
            }
        }
    }

    private func confirm(importID: String, candidateIDs: [String]) -> Effect<Action> {
        .run { [placeImportClient] send in
            do {
                try await placeImportClient.confirm(importID: importID, candidateIDs: candidateIDs)
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
