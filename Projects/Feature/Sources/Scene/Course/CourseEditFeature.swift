import ComposableArchitecture
import Domain
import Foundation
import SharedDesignSystem

// MARK: - CourseEditFeature

@Reducer
public struct CourseEditFeature {

    public enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    public enum Wheel: Equatable {
        case date
        case time
    }

    public struct EditablePlace: Equatable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let category: PlaceCategory
        public let address: String

        public init(id: String, name: String, category: PlaceCategory, address: String) {
            self.id = id
            self.name = name
            self.category = category
            self.address = address
        }
    }

    public struct Snapshot: Equatable {
        public let title: String
        public let date: Date
        public let time: DateComponents?
        public let placeIDs: [String]

        public init(title: String, date: Date, time: DateComponents?, placeIDs: [String]) {
            self.title = title
            self.date = date
            self.time = time
            self.placeIDs = placeIDs
        }
    }

    public struct DeletedPlace: Equatable {
        public let place: EditablePlace
        public let index: Int

        public init(place: EditablePlace, index: Int) {
            self.place = place
            self.index = index
        }
    }

    // MARK: State

    @ObservableState
    public struct State: Equatable {
        public let dateCourseID: String
        public var loadState: LoadState
        public var version: Int
        public var title: String
        public var scheduledDate: Date
        public var scheduledTime: DateComponents?
        /// 자정을 넘겨도 하한과 초기값이 다른 날을 가리키지 않게, 한 번 센 내일로 둔다
        public var tomorrow: DateComponents
        public var places: [EditablePlace]
        public var entry: Snapshot?
        public var pendingUndo: DeletedPlace?
        public var activeWheel: Wheel?
        public var draftDate: DateComponents
        public var draftTime: DateComponents
        public var isBackModalPresented: Bool
        public var isSaving: Bool
        public var toast: ToastState?

        public init(dateCourseID: String, now: Date = Date()) {
            var seoul = Calendar(identifier: .gregorian)
            seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
            let tomorrowDate = seoul.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrow = seoul.dateComponents([.year, .month, .day], from: tomorrowDate)
            let nowTime = Calendar.current.dateComponents([.hour, .minute], from: now)
            self.dateCourseID = dateCourseID
            self.loadState = .loading
            self.version = 0
            self.title = ""
            self.scheduledDate = now
            self.scheduledTime = nil
            self.tomorrow = tomorrow
            self.places = []
            self.entry = nil
            self.pendingUndo = nil
            self.activeWheel = nil
            self.draftDate = tomorrow
            self.draftTime = nowTime
            self.isBackModalPresented = false
            self.isSaving = false
            self.toast = nil
        }
    }

    // MARK: Action

    public enum Action: Equatable {
        case onAppear
        case courseResponse(Result<DateCourse, CourseError>)
        case retryTapped

        case titleChanged(String)
        case dateFieldTapped
        case timeFieldTapped
        case wheelDraftChanged(Wheel, DateComponents)
        case wheelConfirmed
        case wheelDismissed

        case placeMoved(from: Int, to: Int)
        case placeDeleteTapped(id: String)
        case undoTapped
        case toastDismissed
        case addPlaceTapped
        case placesAdded([CoursePlaceCandidate])

        case saveTapped
        case backTapped
        case backModalClosed
        case backModalDiscarded
        case backModalSaveTapped
        case saveResponse(Result<DateCourse, CourseError>)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case placeAddRequested(excluding: [String])
            case saved(DateCourse)
            case dismissed
            case conflicted
            case sessionExpired
        }
    }

    private enum CancelID {
        case load
        case save
    }

    @Dependency(\.courseClient) var courseClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped, .courseResponse:
            return load(state: &state, action: action)
        case .titleChanged, .dateFieldTapped, .timeFieldTapped,
             .wheelDraftChanged, .wheelConfirmed, .wheelDismissed:
            return updateForm(state: &state, action: action)
        case .placeMoved, .placeDeleteTapped, .undoTapped, .toastDismissed,
             .addPlaceTapped, .placesAdded:
            return updatePlaces(state: &state, action: action)
        case .saveTapped, .backTapped, .backModalClosed, .backModalDiscarded,
             .backModalSaveTapped, .saveResponse:
            return save(state: &state, action: action)
        case .delegate:
            return .none
        }
    }
}

// MARK: - Reduce

private extension CourseEditFeature {

    func load(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped:
            guard state.loadState != .loaded else { return .none }
            state.loadState = .loading
            return fetchCourse(id: state.dateCourseID)

        case let .courseResponse(.success(course)):
            state.loadState = .loaded
            state.version = course.version
            state.title = course.title
            state.scheduledDate = course.scheduledDate
            state.scheduledTime = course.scheduledTime
            state.places = course.stops.map(EditablePlace.init(stop:))
            state.entry = Snapshot(
                title: course.title,
                date: course.scheduledDate,
                time: course.scheduledTime,
                placeIDs: course.stops.map(\.place.id)
            )
            return .none

        case let .courseResponse(.failure(error)):
            state.loadState = .failed
            guard error != .unauthorized else {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func fetchCourse(id: String) -> Effect<Action> {
        .run { [courseClient] send in
            do {
                let course = try await courseClient.course(id)
                await send(.courseResponse(.success(course)))
            } catch let error as CourseError {
                await send(.courseResponse(.failure(error)))
            } catch {
                await send(.courseResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    func updateForm(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .titleChanged(title):
            state.title = title
            return .none

        case .dateFieldTapped:
            state.draftDate = Self.dateComponents(from: state.scheduledDate)
            state.activeWheel = .date
            return .none

        case .timeFieldTapped:
            // 기본값을 scheduledTime 에 넣지 않는다. 시간 없는 코스는 칸이 빈 채로 남는다
            state.draftTime = state.scheduledTime ?? state.draftTime
            state.activeWheel = .time
            return .none

        case let .wheelDraftChanged(wheel, components):
            applyDraft(&state, wheel, components)
            return .none

        case .wheelConfirmed:
            confirmWheel(&state)
            return .none

        case .wheelDismissed:
            state.activeWheel = nil
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func updatePlaces(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .placeMoved(from, to):
            guard state.places.indices.contains(from) else { return .none }
            let moved = state.places.remove(at: from)
            state.places.insert(moved, at: min(to, state.places.count))
            return .none

        case let .placeDeleteTapped(id):
            guard let index = state.places.firstIndex(where: { $0.id == id }) else { return .none }
            let removed = state.places.remove(at: index)
            state.pendingUndo = DeletedPlace(place: removed, index: index)
            state.toast = ToastState(message: "'\(removed.name)' 삭제", actionTitle: "실행취소")
            return .none

        case .undoTapped:
            guard let undo = state.pendingUndo else { return .none }
            state.places.insert(undo.place, at: min(undo.index, state.places.count))
            state.pendingUndo = nil
            state.toast = nil
            return .none

        case .toastDismissed:
            state.toast = nil
            state.pendingUndo = nil
            return .none

        case .addPlaceTapped:
            return .send(.delegate(.placeAddRequested(excluding: state.places.map(\.id))))

        case let .placesAdded(candidates):
            let existing = Set(state.places.map(\.id))
            state.places.append(
                contentsOf: candidates
                    .filter { !existing.contains($0.id) }
                    .map(EditablePlace.init(candidate:))
            )
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func save(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .saveTapped, .backModalSaveTapped:
            guard state.canSave else { return .none }
            state.isBackModalPresented = false
            state.isSaving = true
            return updateCourse(state: state)

        case let .saveResponse(.success(course)):
            state.isSaving = false
            return .send(.delegate(.saved(course)))

        case let .saveResponse(.failure(error)):
            state.isSaving = false
            switch error {
            case .conflict:
                return .send(.delegate(.conflicted))
            case .unauthorized:
                return .send(.delegate(.sessionExpired))
            default:
                state.toast = ToastState(message: "저장하지 못했어요. 다시 시도해 주세요")
                return .none
            }

        case .backTapped:
            guard state.hasChanges else { return .send(.delegate(.dismissed)) }
            state.isBackModalPresented = true
            return .none

        case .backModalClosed:
            state.isBackModalPresented = false
            return .none

        case .backModalDiscarded:
            state.isBackModalPresented = false
            return .send(.delegate(.dismissed))

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func applyDraft(_ state: inout State, _ wheel: Wheel, _ components: DateComponents) {
        switch wheel {
        case .date: state.draftDate = components
        case .time: state.draftTime = components
        }
    }

    func confirmWheel(_ state: inout State) {
        switch state.activeWheel {
        case .date:
            state.scheduledDate = Self.dateOnly(from: state.draftDate)
        case .time:
            state.scheduledTime = state.draftTime
        case .none:
            break
        }
        state.activeWheel = nil
    }

    func updateCourse(state: State) -> Effect<Action> {
        let id = state.dateCourseID
        let content = DateCourseContent(
            title: state.title,
            date: state.scheduledDate,
            time: state.scheduledTime,
            placeIDs: state.places.map(\.id)
        )
        let version = state.version
        return .run { [courseClient] send in
            do {
                let course = try await courseClient.updateCourse(
                    id,
                    content,
                    version
                )
                await send(.saveResponse(.success(course)))
            } catch let error as CourseError {
                await send(.saveResponse(.failure(error)))
            } catch {
                await send(.saveResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.save, cancelInFlight: true)
    }

    static func dateComponents(from date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        return calendar.dateComponents([.year, .month, .day], from: date)
    }

    static func dateOnly(from date: DateComponents) -> Date {
        var midnight = date
        midnight.hour = 0
        midnight.minute = 0
        midnight.second = 0
        midnight.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar(identifier: .gregorian).date(from: midnight) ?? Date.distantPast
    }
}

// MARK: - EditablePlace

extension CourseEditFeature.EditablePlace {
    init(stop: Domain.CourseStop) {
        self.init(
            id: stop.place.id,
            name: stop.place.name,
            category: stop.place.category,
            address: stop.place.roadAddress.isEmpty
                ? stop.place.address
                : stop.place.roadAddress
        )
    }

    init(candidate: CoursePlaceCandidate) {
        self.init(
            id: candidate.id,
            name: candidate.name,
            category: candidate.category,
            address: candidate.address
        )
    }
}

// MARK: - Derived

public extension CourseEditFeature.State {

    var hasChanges: Bool {
        guard let entry else { return false }
        return entry.title != title
            || entry.date != scheduledDate
            || entry.time != scheduledTime
            || entry.placeIDs != places.map(\.id)
    }

    var canSave: Bool {
        loadState == .loaded
            && !isSaving
            && !places.isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var timeText: String? {
        guard let scheduledTime, let hour = scheduledTime.hour, let minute = scheduledTime.minute else {
            return nil
        }
        let isMorning = hour < 12
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%@ %d:%02d", isMorning ? "오전" : "오후", hour12, minute)
    }

    var dateText: String? {
        let parts = CourseEditFeature.dateComponents(from: scheduledDate)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }
}
