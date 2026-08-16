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
        public var phase: Phase
        public var selectedIDs: Set<Int>

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

        public init(phase: Phase = .loading, selectedIDs: Set<Int> = []) {
            self.phase = phase
            self.selectedIDs = selectedIDs
        }
    }

    public enum Action: Equatable {
        case onAppear
        case candidateToggled(Int)
        case saveTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case closed
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .candidateToggled(id):
                if state.selectedIDs.contains(id) {
                    state.selectedIDs.remove(id)
                } else {
                    state.selectedIDs.insert(id)
                }
                return .none

            case .saveTapped:
                return .none

            case .closeTapped:
                return .send(.delegate(.closed))

            case .delegate:
                return .none
            }
        }
    }
}
