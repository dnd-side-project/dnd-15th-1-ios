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
    }

    // 첫 조회 5초 대기 후 2초 간격 조회
    private let initialDelay = 5
    private let pollInterval = 2
    private let maxPollCount = 60

    @Dependency(\.placeImportClient) var placeImportClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
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
                guard let importId = state.importId else { return .none }
                return confirm(importId: importId, candidateIDs: Array(state.selectedIDs))

            case .confirmed(.success):
                return .run { [dismiss] _ in await dismiss() }

            case .confirmed(.failure):
                return .none

            case .closeTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }

    private func applyImport(state: inout State, placeImport: PlaceImport) -> Effect<Action> {
        state.importId = placeImport.importId

        switch placeImport.nextAction {
        case .wait:
            guard state.pollCount < maxPollCount else {
                state.phase = .failed
                return .none
            }
            state.pollCount += 1
            let delay = state.pollCount == 1 ? initialDelay : pollInterval
            return poll(importId: placeImport.importId, after: delay)

        case .selectPlaces:
            state.phase = .loaded(placeImport)
            state.selectedIDs = Set(placeImport.candidates.map(\.candidateId))
            return .none

        case .retry:
            state.phase = .failed
            return .none
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
