import Domain
import Foundation
import ThirdParty

/// 게시글 상세. 지도 시트의 한 갈래로 붙는다.
///
/// 어느 탭의 자식도 아니다. 화면 밖으로 나가는 일은 전부 `delegate` 로 올린다
@Reducer
public struct PostDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let contentID: String
        public var detail: PostDetailContent?

        /// 화면 안에서만 뒤집는 북마크. 서버에 켜기·끄기 계약이 없다.
        /// 시트를 닫았다 열면 서버 값으로 돌아간다
        public var savedPlaceIDs: Set<String> = []

        /// 본문을 전문으로 보일지. 시트 단계와는 무관하다
        public var isExpanded = false

        public var isLoading = false
        public var loadFailed = false

        /// 다시 부를 필요가 있는지. 흐름과 화면이 각자 `onAppear` 를 보내 두 번 오는 걸 여기서 막는다
        var needsLoad: Bool {
            detail == nil && !isLoading
        }

        public init(contentID: String) {
            self.contentID = contentID
        }
    }

    public enum Action: Equatable {
        case onAppear
        case detailResponse(PostDetailContent)
        case detailFailed(ExploreError)
        case retryTapped
        case expandToggled
        case closeTapped
        case placeTapped(String)
        case placeBookmarkTapped(String)
        case placeSaveFailed(id: String, wasSaved: Bool)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 상세를 받아왔다. 지도가 이 places 로 핀·카메라를 세운다
            case detailLoaded(PostDetailContent)
            /// `X` 탭. 지도가 시트를 `저장한 장소` 로 되돌린다
            case closeRequested
            /// 행 탭. 받는 쪽은 Cycle 2 다
            case placeSelected(String)
            /// 세션 만료. RootFlow 까지 올라가 로그인으로 되돌린다
            case sessionExpired
        }
    }

    private enum CancelID: Hashable {
        case load
        case save(String)
    }

    @Dependency(\.postDetailContentClient) var postDetailContentClient
    @Dependency(\.placeClient) var placeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped:
            return startLoad(state: &state)

        case let .detailResponse(detail):
            state.detail = detail
            state.savedPlaceIDs = Set(detail.places.filter(\.isSaved).map(\.id))
            state.isLoading = false
            state.loadFailed = false
            // 지도가 이 상세의 places 로 핀·카메라를 세우도록 올린다. 지도 밖 표시자는 무시한다
            return .send(.delegate(.detailLoaded(detail)))

        case let .detailFailed(error):
            state.isLoading = false
            state.loadFailed = true
            // 인증 만료만 상위로 올린다. 다시 시도해도 안 풀리는 실패다
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        case .expandToggled:
            state.isExpanded.toggle()
            return .none

        case .closeTapped:
            return .send(.delegate(.closeRequested))

        case let .placeTapped(id):
            return .send(.delegate(.placeSelected(id)))

        case let .placeBookmarkTapped(id):
            return toggleSave(state: &state, id: id)

        case let .placeSaveFailed(id, wasSaved):
            // 서버 실패 → 미리 뒤집었던 표시를 되돌린다
            if wasSaved {
                state.savedPlaceIDs.insert(id)
            } else {
                state.savedPlaceIDs.remove(id)
            }
            return .none

        case .delegate:
            return .none
        }
    }

    /// 저장 버튼. 먼저 표시를 뒤집고 서버를 부른다. 실패하면 되돌린다
    private func toggleSave(state: inout State, id: String) -> Effect<Action> {
        guard let place = state.detail?.places.first(where: { $0.id == id }) else { return .none }
        let wasSaved = state.savedPlaceIDs.contains(id)
        // 저장하려는데 카카오 식별자가 없으면 부를 수 없다
        if !wasSaved, place.kakaoPlaceID == nil { return .none }
        if wasSaved {
            state.savedPlaceIDs.remove(id)
        } else {
            state.savedPlaceIDs.insert(id)
        }
        return runSave(place, wasSaved: wasSaved)
    }

    private func runSave(_ place: PostDetailPlace, wasSaved: Bool) -> Effect<Action> {
        .run { [placeClient] send in
            do {
                if wasSaved {
                    try await placeClient.removePlace(place.id)
                } else if let kakaoID = place.kakaoPlaceID {
                    _ = try await placeClient.savePlace(kakaoID, place.name, nil, nil)
                }
            } catch {
                await send(.placeSaveFailed(id: place.id, wasSaved: wasSaved))
            }
        }
        // 같은 장소를 연달아 누르면 앞 요청은 버린다
        .cancellable(id: CancelID.save(place.id), cancelInFlight: true)
    }

    /// 흐름과 화면이 각자 `onAppear` 를 보낸다. 두 번째는 버린다.
    /// 다시 시도는 실패 화면에서만 눌리고, 그때는 값도 없고 부르는 중도 아니라 늘 통과한다
    private func startLoad(state: inout State) -> Effect<Action> {
        guard state.needsLoad else { return .none }
        state.isLoading = true
        state.loadFailed = false
        return load(id: state.contentID)
    }

    private func load(id: String) -> Effect<Action> {
        .run { [postDetailContentClient] send in
            do {
                await send(.detailResponse(try await postDetailContentClient.contentDetail(id)))
            } catch let error as ExploreError {
                await send(.detailFailed(error))
            } catch {
                // ExploreError 가 아닌 것을 network 로 부르면 원인을 잘못 이름 붙인다
                await send(.detailFailed(.unknown))
            }
        }
        // 같은 시트를 빨리 두 번 열면 늦게 온 옛 응답이 새 응답을 덮는다
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
}
