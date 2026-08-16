@testable import Feature
import ThirdParty
import XCTest

final class FeatureLogClassificationTests: XCTestCase {
    func test_프레젠테이션상태_표시_해제_언랩() {
        struct SearchState: Equatable {
            var query = ""
        }

        struct HostState: Equatable {
            var search: PresentationState<SearchState> = PresentationState(wrappedValue: nil)
            var presentedTerms: PresentationState<String> = PresentationState(wrappedValue: nil)
            var isLoading = false
        }

        let dismissed = HostState()
        var presented = HostState()
        presented.search = PresentationState(wrappedValue: SearchState(query: "cafe"))
        presented.presentedTerms = PresentationState(wrappedValue: "terms")
        presented.isLoading = true

        let presentChanges = FeatureLogStateDiff.changedFields(from: dismissed, to: presented)
        XCTAssertEqual(
            presentChanges.first(where: { $0.field == "search" })?.from,
            "nil"
        )
        XCTAssertEqual(
            presentChanges.first(where: { $0.field == "search" })?.to,
            "presented"
        )
        XCTAssertEqual(
            presentChanges.first(where: { $0.field == "presentedTerms" })?.from,
            "nil"
        )
        XCTAssertEqual(
            presentChanges.first(where: { $0.field == "presentedTerms" })?.to,
            "presented"
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(
                field: "search",
                from: presentChanges.first(where: { $0.field == "search" })?.from ?? "",
                to: presentChanges.first(where: { $0.field == "search" })?.to ?? ""
            ),
            .present
        )

        let dismissChanges = FeatureLogStateDiff.changedFields(from: presented, to: dismissed)
        XCTAssertEqual(
            dismissChanges.first(where: { $0.field == "search" })?.from,
            "presented"
        )
        XCTAssertEqual(
            dismissChanges.first(where: { $0.field == "search" })?.to,
            "nil"
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(
                field: "presentedTerms",
                from: dismissChanges.first(where: { $0.field == "presentedTerms" })?.from ?? "",
                to: dismissChanges.first(where: { $0.field == "presentedTerms" })?.to ?? ""
            ),
            .dismiss
        )

        // Direct unwrap helper: nil vs non-nil
        let nilWrapped = FeatureLogStateDiff.unwrapPresentationValue(
            PresentationState<SearchState>(wrappedValue: nil)
        )
        XCTAssertEqual(FeatureLog.summarizeValue(nilWrapped), "nil")

        let valueWrapped = FeatureLogStateDiff.unwrapPresentationValue(
            PresentationState(wrappedValue: SearchState(query: "x"))
        )
        XCTAssertNotEqual(FeatureLog.summarizeValue(valueWrapped), "nil")
    }

    func test_액션로그판정_자식스코프이름_제외() {
        let childScopes = [
            "auth", "mainTab", "home", "explore", "map",
            "myPage", "appIntro", "overlay", "search", "delegate"
        ]

        for name in childScopes {
            XCTAssertFalse(
                FeatureLogActionParser.shouldLogAction(.init(name: name, payload: nil)),
                "expected child-scope action `\(name)` to be skipped"
            )
        }

        XCTAssertTrue(
            FeatureLogActionParser.shouldLogAction(.init(name: "loginButtonTapped", payload: "provider=apple"))
        )
        XCTAssertTrue(
            FeatureLogActionParser.shouldLogAction(.init(name: "tabSelected", payload: "home"))
        )
        XCTAssertTrue(
            FeatureLogActionParser.shouldLogAction(.init(name: "loginResponse", payload: "result=failure"))
        )
    }

    func test_실패정보_리프_로그인응답실패() {
        enum SampleAction {
            case loginResponse(Result<String, SampleError>)
            case onAppear
        }

        enum SampleError: Error, Equatable {
            case network
            case cancelled
        }

        let parsed = FeatureLogActionParser.nameAndPayload(
            SampleAction.loginResponse(.failure(.network))
        )
        let failure = FeatureLogActionParser.failureInfo(
            from: SampleAction.loginResponse(.failure(.network)),
            parsed: parsed
        )

        XCTAssertEqual(parsed.name, "loginResponse")
        XCTAssertEqual(failure?.operation, "login")
        XCTAssertEqual(failure?.error, "network")

        let successParsed = FeatureLogActionParser.nameAndPayload(
            SampleAction.loginResponse(.success("ok"))
        )
        XCTAssertNil(
            FeatureLogActionParser.failureInfo(
                from: SampleAction.loginResponse(.success("ok")),
                parsed: successParsed
            )
        )

        let appearParsed = FeatureLogActionParser.nameAndPayload(SampleAction.onAppear)
        XCTAssertNil(
            FeatureLogActionParser.failureInfo(
                from: SampleAction.onAppear,
                parsed: appearParsed
            )
        )
    }

    func test_실패정보_중첩_자식액션은_부모오류아님() {
        enum AuthAction {
            case loginResponse(Result<String, SampleError>)
            case loginButtonTapped
        }

        enum ParentAction {
            case auth(AuthAction)
            case myPage(AuthAction)
            case mainTab(AuthAction)
            case sessionRestored(Result<String?, SampleError>)
            case tabSelected
        }

        enum SampleError: Error, Equatable {
            case network
            case unknown
        }

        let nested = ParentAction.auth(.loginResponse(.failure(.network)))
        let nestedParsed = FeatureLogActionParser.nameAndPayload(nested)
        XCTAssertEqual(nestedParsed.name, "auth")
        XCTAssertFalse(FeatureLogActionParser.shouldLogAction(nestedParsed))
        XCTAssertNil(
            FeatureLogActionParser.failureInfo(from: nested, parsed: nestedParsed),
            "parent wrapper must not classify nested child failure as parent Error"
        )

        let myPageNested = ParentAction.myPage(.loginResponse(.failure(.network)))
        let myPageParsed = FeatureLogActionParser.nameAndPayload(myPageNested)
        XCTAssertEqual(myPageParsed.name, "myPage")
        XCTAssertFalse(FeatureLogActionParser.shouldLogAction(myPageParsed))
        XCTAssertNil(FeatureLogActionParser.failureInfo(from: myPageNested, parsed: myPageParsed))

        let mainTabNested = ParentAction.mainTab(.loginResponse(.failure(.unknown)))
        let mainTabParsed = FeatureLogActionParser.nameAndPayload(mainTabNested)
        XCTAssertEqual(mainTabParsed.name, "mainTab")
        XCTAssertFalse(FeatureLogActionParser.shouldLogAction(mainTabParsed))
        XCTAssertNil(FeatureLogActionParser.failureInfo(from: mainTabNested, parsed: mainTabParsed))

        // Parent-owned Result failure still logs with parent operation.
        let parentOwned = ParentAction.sessionRestored(.failure(.network))
        let parentParsed = FeatureLogActionParser.nameAndPayload(parentOwned)
        let parentFailure = FeatureLogActionParser.failureInfo(from: parentOwned, parsed: parentParsed)
        XCTAssertEqual(parentParsed.name, "sessionRestored")
        XCTAssertTrue(FeatureLogActionParser.shouldLogAction(parentParsed))
        XCTAssertEqual(parentFailure?.operation, "restoreSession")
        XCTAssertEqual(parentFailure?.error, "network")

        let nonFailure = ParentAction.tabSelected
        let nonFailureParsed = FeatureLogActionParser.nameAndPayload(nonFailure)
        XCTAssertNil(FeatureLogActionParser.failureInfo(from: nonFailure, parsed: nonFailureParsed))
    }
}
