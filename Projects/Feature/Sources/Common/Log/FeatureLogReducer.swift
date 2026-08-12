import Foundation
import ThirdParty

extension Reducer {
    /// Feature owner 의 Action / State / Navigation / Error 를 자동 로그하는 higher-order 리듀서.
    ///
    /// owner reducer 에 1회만 부착한다:
    /// ```swift
    /// Reduce { ... }
    /// .logged(as: Self.self)
    /// ```
    @warn_unqualified_access
    func logged(
        as featureType: Any.Type,
        scene: String? = nil
    ) -> FeatureLogReducer<Self> {
        FeatureLogReducer(
            base: self,
            scene: scene ?? FeatureLog.sceneName(from: featureType)
        )
    }
}

struct FeatureLogReducer<Base: Reducer>: Reducer {
    let base: Base
    let scene: String

    #if DEBUG
    // swiftlint:disable:next identifier_name
    func _reduce(
        into state: inout Base.State,
        action: Base.Action
    ) -> Effect<Base.Action> {
        let parsed = FeatureLogActionParser.nameAndPayload(action)
        if FeatureLogActionParser.shouldLogAction(parsed) {
            FeatureLog.action(
                scene: scene,
                name: parsed.name,
                payload: parsed.payload
            )
        }

        let oldState = state
        let effects = base._reduce(into: &state, action: action)
        let changes = FeatureLogStateDiff.changedFields(from: oldState, to: state)

        for change in changes {
            if FeatureLogStateDiff.shouldIgnoreField(change.field) {
                continue
            }

            if let style = FeatureLogStateDiff.navigationStyle(
                field: change.field,
                from: change.from,
                to: change.to
            ) {
                FeatureLog.navigation(
                    scene: scene,
                    field: change.field,
                    from: change.from,
                    to: change.to,
                    style: style
                )
            } else {
                FeatureLog.state(
                    scene: scene,
                    field: change.field,
                    from: change.from,
                    to: change.to
                )
            }
        }

        if let failure = FeatureLogActionParser.failureInfo(from: action, parsed: parsed) {
            let userVisible = FeatureLogStateDiff.becameUserVisible(from: changes)
            FeatureLog.error(
                scene: scene,
                operation: failure.operation,
                error: failure.error,
                userVisible: userVisible
            )
        }

        return effects
    }
    #else
    // swiftlint:disable:next identifier_name
    func _reduce(
        into state: inout Base.State,
        action: Base.Action
    ) -> Effect<Base.Action> {
        base._reduce(into: &state, action: action)
    }
    #endif
}

enum FeatureLogActionParser {
    struct Parsed: Equatable {
        var name: String
        var payload: String?
    }

    struct FailureInfo: Equatable {
        var operation: String
        var error: String
    }

    /// leaf reducer 가 소유하는 child-scope / presentation / delegate case.
    /// parent 는 이를 Action / Error 로 다시 로그하지 않는다.
    private static let childScopeActionNames: Set<String> = [
        "auth",
        "mainTab",
        "home",
        "explore",
        "map",
        "myPage",
        "appIntro",
        "overlay",
        "search",
        "delegate"
    ]

    static func nameAndPayload(_ action: Any) -> Parsed {
        let mirror = Mirror(reflecting: action)

        if mirror.displayStyle == .enum {
            if let child = mirror.children.first {
                let name = child.label ?? String(describing: action)
                let payload = payloadSummary(from: child.value)
                return Parsed(name: name, payload: payload)
            }

            // 연관값 없는 enum case: description 이 case 이름이다.
            return Parsed(name: String(describing: action), payload: nil)
        }

        // 중첩/예외 형태: 가능한 범위에서 case 토큰으로 보정.
        let description = String(describing: action)
        let name = description.split(separator: "(").first.map(String.init) ?? description
        return Parsed(name: name, payload: nil)
    }

    static func shouldLogAction(_ parsed: Parsed) -> Bool {
        // child-scope wrapper 와 pure delegate 전달은 leaf reducer 소유.
        !childScopeActionNames.contains(parsed.name)
    }

    static func failureInfo(from action: Any, parsed: Parsed) -> FailureInfo? {
        // 중첩 child action (예: auth(.loginResponse(.failure))) 은 leaf owner 가 처리.
        guard childScopeActionNames.contains(parsed.name) == false else {
            return nil
        }

        guard let associatedValue = rootAssociatedValue(of: action) else {
            return nil
        }

        // action 자신의 연관값만 Result.failure / failure(...) 로 본다.
        // 중첩 child action 트리를 "failure" 문자열로 탐색하지 않는다.
        guard let error = rootFailureToken(from: associatedValue) else {
            return nil
        }

        return FailureInfo(
            operation: FeatureLog.operationName(fromActionName: parsed.name),
            error: error
        )
    }

    // MARK: - 페이로드

    private static func payloadSummary(from associatedValue: Any) -> String? {
        let mirror = Mirror(reflecting: associatedValue)

        if mirror.displayStyle == .tuple {
            let parts = mirror.children.compactMap { child -> String? in
                guard let label = child.label, isLabeledArgument(label) else {
                    // 라벨 없는 연관값도 요약 토큰으로 남긴다.
                    return FeatureLog.summarizeValue(child.value)
                }
                return "\(label)=\(FeatureLog.summarizeValue(child.value))"
            }
            let joined = parts.joined(separator: ", ")
            return joined.isEmpty ? nil : joined
        }

        if mirror.displayStyle == .enum {
            // 예: Result.failure(Error.network) / Result.success(...)
            if let child = mirror.children.first, let label = child.label {
                if label == "failure" || label == "success" {
                    return "result=\(label)"
                }
                return "\(label)=\(FeatureLog.summarizeValue(child.value))"
            }
            return FeatureLog.summarizeValue(associatedValue)
        }

        // 단일 unlabeled 연관값 (예: loginButtonTapped(AuthProvider.apple)).
        return FeatureLog.summarizeValue(associatedValue)
    }

    private static func isLabeledArgument(_ label: String) -> Bool {
        // Swift Mirror 는 unlabeled tuple 요소를 ".0", ".1" 로 표현한다.
        label.firstIndex(where: { $0 != "." && !$0.isNumber }) != nil
    }

    // MARK: - Root failure 탐지

    private static func rootAssociatedValue(of action: Any) -> Any? {
        let mirror = Mirror(reflecting: action)
        guard mirror.displayStyle == .enum else {
            return nil
        }
        return mirror.children.first?.value
    }

    /// action payload root 에서만 Result.failure 를 탐지한다.
    /// `auth(.loginResponse(.failure))` 같은 중첩 wrapper 는 의도적으로 nil.
    private static func rootFailureToken(from associatedValue: Any) -> String? {
        var value = associatedValue
        var mirror = Mirror(reflecting: value)

        // Optional 한 겹이 있으면 먼저 푼다.
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else {
                return nil
            }
            value = child.value
            mirror = Mirror(reflecting: value)
        }

        if mirror.displayStyle == .enum, let child = mirror.children.first {
            // Result.failure(Error) / Result.success(...)
            if child.label == "failure" {
                return leafErrorToken(child.value)
            }
            // root payload 가 Result case 가 아니면 중첩 action 으로 내려가지 않는다.
            return nil
        }

        // Mirror 로 안 잡히는 Result-like 값의 최후 보정. 이 root 만 대상.
        let description = String(describing: value)
        if description.hasPrefix("failure(") || description.hasPrefix(".failure(") {
            return failureToken(fromDescription: description) ?? "failure"
        }

        return nil
    }

    private static func leafErrorToken(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)

        if mirror.displayStyle == .enum {
            if let child = mirror.children.first {
                // enum case 라벨 우선 (network / cancelled / ...)
                if let label = child.label, label.isEmpty == false {
                    return lastPathComponent(label)
                }
                return lastPathComponent(String(describing: child.value))
            }
            return lastPathComponent(String(describing: value))
        }

        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return leafErrorToken(child.value)
            }
            return "nil"
        }

        return lastPathComponent(String(describing: value))
    }

    private static func failureToken(fromDescription description: String) -> String? {
        // "...failure(Some.Error.network)" / "failure(network)" 형태 매칭
        guard let regex = try? NSRegularExpression(
            pattern: #"failure\(([^)]+)\)"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(description.startIndex..<description.endIndex, in: description)
        guard let match = regex.firstMatch(in: description, options: [], range: range),
              match.numberOfRanges > 1,
              let tokenRange = Range(match.range(at: 1), in: description)
        else {
            return nil
        }

        return lastPathComponent(String(description[tokenRange]))
    }

    private static func lastPathComponent(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.split(separator: ".").last {
            return String(last)
        }
        return trimmed
    }
}

enum FeatureLogStateDiff {
    struct Change: Equatable {
        var field: String
        var from: String
        var to: String
    }

    private static let ignoredParentFields: Set<String> = [
        "home", "explore", "map", "myPage",
        "appIntro", "loggedOutAuth", "mainTab", "overlay",
        "appCoordinator"
    ]

    private static let presentationFields: Set<String> = [
        "search",
        "presentedTerms"
    ]

    private static let userVisibleFields: Set<String> = [
        "toast",
        "errorMessage"
    ]

    /// `@ObservableState` / property wrapper 의 Mirror storage 라벨을 정규화한다.
    ///
    /// - `_isLoading` → `isLoading`
    /// - `_$observationRegistrar` 등 `_$...` bookkeeping → 무시 (`nil`)
    static func normalizedFieldLabel(_ label: String) -> String? {
        if label.hasPrefix("_$") {
            return nil
        }
        if label.hasPrefix("_"), label.count > 1 {
            return String(label.dropFirst())
        }
        return label
    }

    static func changedFields<State>(from old: State, to new: State) -> [Change] {
        let oldChildren = topLevelChildren(of: old)
        let newChildren = topLevelChildren(of: new)

        // 기존 state mirror 선언 순서를 유지하고, 새 필드는 뒤에 붙인다.
        var fields: [String] = []
        var seen = Set<String>()
        for (key, _) in orderedTopLevelChildren(of: old) where seen.insert(key).inserted {
            fields.append(key)
        }
        for (key, _) in orderedTopLevelChildren(of: new) where seen.insert(key).inserted {
            fields.append(key)
        }

        var changes: [Change] = []
        for field in fields {
            let fromValue = oldChildren[field]
            let toValue = newChildren[field]

            let fromSummary = summary(for: field, value: fromValue)
            let toSummary = summary(for: field, value: toValue)

            if fromSummary == toSummary {
                continue
            }

            changes.append(
                Change(
                    field: field,
                    from: fromSummary,
                    to: toSummary
                )
            )
        }

        return changes
    }

    static func shouldIgnoreField(_ field: String) -> Bool {
        ignoredParentFields.contains(field)
    }

    static func navigationStyle(
        field: String,
        from: String,
        to: String
    ) -> FeatureLog.NavigationStyle? {
        switch field {
        case "phase":
            return .phase
        case "selectedTab":
            return .tab
        case "pendingDeepLink":
            return .deepLink
        default:
            break
        }

        guard presentationFields.contains(field) else {
            return nil
        }

        if from == "nil", to != "nil" {
            return .present
        }
        if from != "nil", to == "nil" {
            return .dismiss
        }
        // value → value presentation 갱신도 present navigation 으로 본다.
        if from != "nil", to != "nil" {
            return .present
        }
        return nil
    }

    static func becameUserVisible(from changes: [Change]) -> Bool {
        changes.contains { change in
            userVisibleFields.contains(change.field)
                && change.from == "nil"
                && change.to != "nil"
        }
    }

    // MARK: - 비공개

    private static func topLevelChildren(of value: Any) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: orderedTopLevelChildren(of: value))
    }

    private static func orderedTopLevelChildren(of value: Any) -> [(String, Any)] {
        var result: [(String, Any)] = []
        var seen = Set<String>()
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label else { continue }
            guard let field = normalizedFieldLabel(label) else { continue }
            if seen.insert(field).inserted {
                result.append((field, unwrapPresentationValue(child.value)))
            }
        }

        // 일부 wrapper 는 superclass mirror 뒤에 멤버를 둔다.
        if let superclassMirror = mirror.superclassMirror {
            for child in superclassMirror.children {
                guard let label = child.label else { continue }
                guard let field = normalizedFieldLabel(label) else { continue }
                if seen.insert(field).inserted {
                    result.append((field, unwrapPresentationValue(child.value)))
                }
            }
        }

        return result
    }

    /// TCA `PresentationState`(`@Presents`) 를 가능하면 optional wrapped value 로 푼다.
    /// wrapper 형태를 모르면 원본 값을 그대로 쓴다.
    static func unwrapPresentationValue(_ value: Any) -> Any {
        if isPresentationState(value) {
            return presentationWrappedValue(from: value) as Any
        }
        return value
    }

    private static func isPresentationState(_ value: Any) -> Bool {
        let typeName = String(describing: type(of: value))
        // 예: PresentationState<SearchFeature.State>
        return typeName.hasPrefix("PresentationState<") || typeName == "PresentationState"
    }

    private static func presentationWrappedValue(from value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)

        // 우선: Mirror 가 노출하면 public `wrappedValue` 사용.
        if let child = mirror.children.first(where: { $0.label == "wrappedValue" }) {
            return optionalPayload(from: child.value)
        }

        // TCA PresentationState 는 optional state 를 private `storage` 에 둔다.
        if let storageChild = mirror.children.first(where: { $0.label == "storage" }) {
            let storageMirror = Mirror(reflecting: storageChild.value)
            if let stateChild = storageMirror.children.first(where: { $0.label == "state" }) {
                return optionalPayload(from: stateChild.value)
            }
            if let first = storageMirror.children.first {
                return optionalPayload(from: first.value)
            }
        }

        // 최후: non-nil description 이면 presented payload 로 본다.
        let summarized = FeatureLog.summarizeValue(value)
        return summarized == "nil" ? nil : value
    }

    private static func optionalPayload(from value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            return mirror.children.first?.value
        }
        return value
    }

    private static func summary(for field: String, value: Any?) -> String {
        guard let value else {
            return "nil"
        }

        // Presentation 필드: 이미 unwrapped optional / PresentationState payload.
        // non-nil 은 중첩 state dump 를 피하려고 "presented" 로 요약.
        if presentationFields.contains(field) {
            let summarized = FeatureLog.summarizeValue(value)
            return summarized == "nil" ? "nil" : "presented"
        }

        // Navigation enum 은 ".main" 형태로 찍히는 경우가 많아 짧은 토큰만 유지.
        return FeatureLog.summarizeValue(value)
    }
}
