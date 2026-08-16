# Conventions

코드/Git 작성 시 바로 보는 규칙.
구조/의존/흐름은 [ARCHITECTURE.md](ARCHITECTURE.md) 를 본다.

기준:
- 팀 FE 컨벤션 (Git commit / branch)
- StyleShare 계열 Swift 스타일 + 현재 스택(SwiftUI, TCA, async/await)

---

## a. Coding Convention

### 1. 코드 레이아웃

포맷과 안전성은 `.swiftlint.yml` 이 유일본이다. 문서에 다시 적지 않는다.

문서가 정하는 것은 린트가 못 잡는 둘뿐이다.

- 한 줄이 길면 파라미터/인자 기준으로 줄바꿈한다
- `// MARK: -` 위아래에 빈 줄을 둔다

### 2. 명명

공통:

| 대상 | 규칙 |
|---|---|
| 타입 | `UpperCamelCase` |
| 함수/변수/enum case | `lowerCamelCase` |
| Boolean | `is` / `has` / `should` / `can` |
| 약어 | 시작이면 소문자, 이어지면 대문자 (`userID`, `urlString`) |
| 함수명 앞 `get` | 금지 |

```swift
// ✅
func name(for user: User) -> String
func fetchUser() async throws -> User

// ❌
func getName(for user: User) -> String
```

모듈 목록은 [ARCHITECTURE.md](ARCHITECTURE.md) §1 을 본다.

계층 타입:

| 계층 | 패턴 | 예 |
|---|---|---|
| Domain entity | 명사 | `AuthSession` |
| Domain client | `*Client` | `AuthClient` |
| Domain error | `*Error` | `AuthError` |
| Data DTO | `*DTO` | `AuthSessionDTO` |
| Data data source | `*DataSource` | `AuthLocalDataSource` |
| Data repository | `*Repository` | `AuthRepository` |
| Core default impl | `Default*` | `DefaultKeychainStorage` |
| Data factory | `*ClientFactory` | `AuthClientFactory` |
| App infra | `InfraContainer` | `InfraContainer.make()` |
| Feature reducer | `*Feature` | `HomeFeature` |
| Feature view | `*View` | `HomeView` |

DataSource 프로퍼티:

```text
authLocal
authRemote
```

TCA Action 은 이벤트 중심:

```text
loginButtonTapped
logoutButtonTapped
onAppear
```

### 3. 타입 / 클로저 / 접근 제어

- 상속 없는 class 는 `final`
- 접근 제어는 좁게 (`private` 우선)
- 값 타입 우선
- 파라미터/리턴 없는 클로저: `() -> Void`
- `async/await` 우선, GCD 남용 금지

```swift
let completion: () -> Void = { ... }
```

### 4. 주석

| 종류 | 사용 |
|---|---|
| `///` | public API / 타입 의도 |
| `// MARK: -` | 파일 섹션 |
| `//` | 비자명한 이유만 |
| `// TODO:` | 최소화 |

쓸데없는 주석 금지.

### 5. SwiftUI / TCA

- View 는 작고 단순하게
- 화면 상태 본체는 TCA Feature reducer
- View 는 렌더링 + `store.send` 중심
- DependencyClient 정의는 Domain, live 주입은 App

```swift
Button("Login") {
    store.send(.loginButtonTapped)
}
```


### Feature Logging

Feature 로그는 케이스별 수동 호출이 아니라 reducer 자동 로그를 쓴다.

```swift
public var body: some ReducerOf<Self> {
    Reduce { state, action in
        // ...
    }
    .logged(as: Self.self)
}
```

규칙:

1. owner reducer 에 1회만 부착
2. RootFeature 는 제외
3. 종류: 사용자 액션 / 상태 변경 / 화면 이동 / 오류
4. category 는 `.feature`
5. 토큰/Authorization/identityToken 금지, userID/provider/route 는 허용

메시지 포맷:

```text
[Feature] [Auth] 사용자 액션: loginButtonTapped(provider=apple)
[Feature] [Auth] 상태 변경: isLoading(false → true)
[Feature] [AppCoordinator] 화면 이동: phase(bootstrapping → main)
[Feature] [Auth] 오류: login(network, userVisible=true)
```

출력 규칙:

1. 전역 직접 로그 (`Logger.shared`) 는 call site 접두를 남긴다  
   예: `[App] [AppBootstrap.swift:17] run() - App bootstrap completed`
2. 모듈 래퍼 로그 (`FeatureLog`, `NetworkLog`) 는 본문만 출력한다  
   예: `[Feature] [MyPage] 상태 변경: userID(2 → nil)`  
   예: `[Network] [Response] ← 200 /api/v1/auth/reissue (617ms, 367B)`

### 6. 폴더

Feature 폴더 배치는 [ARCHITECTURE.md](ARCHITECTURE.md) §3 규칙을 본다.

공용 코드를 어디 둘지는 세 조건으로 판정한다. 셋 다 만족해야 DesignSystem 이다.

| 조건 | 질문 |
|---|---|
| 형태 | 뷰·스타일·디자인 토큰인가 (모델·유틸·확장은 아니다) |
| 의존 | Domain·TCA·ThirdParty SDK 를 모르는가 |
| 결합 | 앱 고유 모델·문구·URL 을 모르는가 (호출자가 넘기는가) |

하나라도 어기면 `Feature` 다. `Extension/` 은 타입 확장(`X+Y.swift`) 전용,
나머지 공용 코드는 `Util/<주제>/` 에 둔다.

규칙:

1. Feature 는 단일 모듈. 기능 분리는 폴더만
2. Scene / child 안은 flat (`*Feature`, `*View`)
3. 파일명 = 메인 타입명
4. 커스텀 폴더는 단수 (`Model`, `Repository`, `Scene`)
5. 표준 컨테이너만 복수 (`Sources`, `Tests`)

### 7. Import / DI

모듈별 허용·금지 의존은 [ARCHITECTURE.md](ARCHITECTURE.md) §1 을 본다.

DI:

1. Feature 의존성은 Domain `*Client` 만
2. Domain `*Client` 의 live 등록은 App DI only. 외부 SDK 초기화는 SDK 를 소유한 모듈이 Bootstrap 타입으로 갖고, App 은 호출만 한다
3. bootstrap / Root store 는 `CompositionRoot` 1회
4. View / `WindowGroup` 안에서 store 생성 금지
5. Feature 코드에 `Repository` / `ClientFactory` 이름 쓰지 않음
6. Data `*ClientFactory.make(...)` 가 Domain client 반환 (App 진입). 내부 조립은 private `make*`
7. `InfraContainer.make()` 로 live 인프라 조립
8. Repository 는 DataSource 를 기본으로 주입하고, SDK credential provider 등 필요 시 Service collaborator 를 함께 주입할 수 있다

### 8. Scene 통신

```text
Root
└─ AppCoordinator
   ├─ loggedOut(Auth)
   ├─ main(MainTab: Home/Explore/Map/MyPage)
   ├─ DeepLink
   └─ Overlay
```

허용:

```text
Scene → parent     : delegate bubble-up
parent → Scene     : command
Scene → Domain     : *Client
URL → DeepLinkRouter → AppCoordinator
```

금지:

```text
SceneA → SceneB 직접 참조/상태 수정
Scene 에서 phase / selectedTab 직접 변경
Scene 에서 URL 파싱 후 다른 Scene 진입
```

```swift
public enum Action {
    case loginButtonTapped
    case delegate(Delegate)

    public enum Delegate: Equatable {
        case loginSucceeded(userID: String)
        case logoutSucceeded
        case sessionExpired
    }
}
```

로컬 에러는 Scene `errorMessage`.  
전역 에러(`sessionExpired` 등)만 AppCoordinator 로 승격.

### 9. 테스트

```text
Feature reducer 테스트
Domain *Client override
test_한글_한글
```

```text
test_세션없음_로그아웃상태복구
test_로그인성공_델리게이트_전달
```

규칙:

1. Feature 테스트에 Data/Core 구현을 끌어오지 않는다
2. Domain/Data 단위 테스트는 기본 강제 없음
3. 고위험 도메인만 보완 테스트 가능

### 10. 새 기능 체크

1. Domain `{Model,Error,Client}`
2. Data `{DTO,DataSource,Endpoint,Mapper,Repository,Service,ClientFactory}` — `DTO/` 아래 `Network`·`Storage` 는 선택
3. App `Dependencies.register`
4. Feature `Scene/<Name>`
5. 필요 시 AppCoordinator / MainTab / DeepLink
6. Feature 테스트

```text
화면? Feature
계약? Domain
구현? Data
인프라? Core
외부 SDK? ThirdParty*
조립? App
```

상세 구조는 [ARCHITECTURE.md](ARCHITECTURE.md).
환경·scheme·Bundle ID 는 [ARCHITECTURE.md](ARCHITECTURE.md) §5 를 본다.

---

## b. Git Commit Convention

### 1. 스타일

형식:

```text
Type: 요약
```

| Type | 설명 |
|---|---|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서 수정 |
| `style` | 코드 의미 없는 스타일만 변경 |
| `refactor` | 리팩토링 |
| `test` | 테스트 추가/수정 |
| `chore` | 설정 변경 등 코드 의미 없는 작업 |

예:

```text
feat: 로그인 버튼 추가
fix: 딥링크 파싱 실패 수정
docs: 컨벤션에 git 규칙 반영
chore: 프로젝트 세팅 스켈레톤 정리
```

필요하면 본문과 이슈 참조를 추가한다.

```text
feat: 사용자 프로필 화면 추가

- 프로필 이미지, 이름 표시
- 팔로우 버튼 추가

Ref: DND-10
```

### 2. 권장

- 커밋은 기능 단위로 쪼갠다
- 첫 줄은 변경 내용이 보이게 쓴다
- 관련 없는 변경을 한 커밋에 섞지 않는다
- `WIP`, `update`, `fix bug` 같은 모호한 메시지 금지

---

## c. Git Branch Strategy

### 1. 브랜치 이름

형식:

```text
Type/Jira티켓
```

```text
feat/dnd-10
fix/dnd-25
refactor/dnd-42
docs/agent-docs
```

- Type 은 commit type 과 동일
- jira key 는 소문자
- Jira 키가 없으면 브랜치 이름에 `no-issue` 를 넣지 않는다. `docs/agent-docs` 처럼 내용을 쓴다.
  `[NO-ISSUE]` 는 PR 제목에만 붙인다

### 2. 브랜치 구조

```text
main
 └ dev
    └ feat/dnd-10
```

| 브랜치 | 역할 |
|---|---|
| `main` | 배포 가능 상태 |
| `dev` | 개발 통합 |
| `Type/Jira티켓` | 작업 브랜치 |

### 3. PR 흐름

1. `dev` 에서 작업 브랜치 생성
2. 기능 단위로 커밋
3. `dev` 로 PR
4. 리뷰 + CI 통과 후 merge
5. 릴리즈 시점에 `dev` → `main`

PR 제목:

```text
[DND-10] 로그인 화면 추가
[NO-ISSUE] 프로젝트 세팅
```

템플릿: [../.github/pull_request_template.md](../.github/pull_request_template.md)

머지 조건:

1. CI 통과
2. 아키텍처 의존 위반 없음
3. 가능하면 리뷰, 급하면 self-merge 허용

---

## d. 관련

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [../AGENTS.md](../AGENTS.md) — 하지 말 것은 `먼저 물을 것` 을 본다
- [../.swiftlint.yml](../.swiftlint.yml)
