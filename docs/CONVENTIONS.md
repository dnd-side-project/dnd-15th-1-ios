# Conventions

코드/Git 작성 시 바로 보는 규칙.
구조/의존/흐름은 [ARCHITECTURE.md](ARCHITECTURE.md) 를 본다.

기준:
- 팀 FE 컨벤션 (Git commit / branch)
- StyleShare 계열 Swift 스타일 + 현재 스택(SwiftUI, TCA, async/await)

---

## a. Coding Convention

### 1. 코드 레이아웃

- 들여쓰기: 4 spaces
- 콜론(`:`)은 오른쪽만 공백
- 연산자 좌우 공백 유지
- 한 줄이 길면 파라미터/인자 기준 줄바꿈
- 한 줄 최대: warning 100 / error 120 (`.swiftlint.yml`)
- 빈 줄에 trailing whitespace 금지
- 파일 끝 개행 유지
- `// MARK: -` 위아래 빈 줄

```swift
let number: Int = 42
let dictionary: [String: Any] = [:]

function(
    firstArgument: "Hello",
    secondArgument: 100
)

guard
    let user = user,
    let name = user.name
else {
    return
}
```

Import:

- 알파벳 정렬
- 시스템 프레임워크 먼저, 그다음 프로젝트/서드파티

```swift
import Foundation
import SwiftUI

import ThirdParty
```

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

모듈:

```text
CoreNetwork, CoreStorage, CoreLogger
SharedUtils, SharedDesignSystem
ThirdParty, ThirdPartyUI, ThirdPartyCore
Domain, Data, Feature, App
```

계층 타입:

| 계층 | 패턴 | 예 |
|---|---|---|
| Domain entity | 명사 | `AuthSession` |
| Domain client | `*Client` | `AuthClient` |
| Domain error | `*Error` | `AuthError` |
| Data DTO | `*DTO` | `AuthSessionDTO` |
| Data datasource | `*Datasource` | `AuthLocalDatasource` |
| Data impl | `*RepositoryImpl` | `AuthRepositoryImpl` |
| Data factory | `*ClientFactory` | `AuthClientFactory` |
| Feature reducer | `*Feature` | `HomeFeature` |
| Feature view | `*View` | `HomeView` |

Datasource 프로퍼티:

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
- 컬렉션 단축 문법 (`[T]`, `[K: V]`)
- force unwrap / IUO 금지
- 파라미터/리턴 없는 클로저: `() -> Void`
- trailing closure 사용
- `async/await` 우선, GCD 남용 금지

```swift
final class DefaultKeychainStorage { ... }
var names: [String] = []
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

### 6. 폴더

```text
Feature/Sources/
  Root/
  AppCoordinator/
    MainTab/
    DeepLink/
    Overlay/
  Common/
  Scene/{Auth,Home,Explore,Map,MyPage}
Feature/Tests/
  AppCoordinator/
  Auth/

Domain/Sources/<Name>/{Model,Error,Client}
Data/Sources/<Name>/{DTO,Datasource,Repository}
App/Sources/
  DulpickApp.swift
  CompositionRoot.swift
  DI/
```

규칙:

1. Feature 는 단일 모듈. 기능 분리는 폴더만
2. Scene / child 안은 flat (`*Feature`, `*View`)
3. 파일명 = 메인 타입명
4. 커스텀 폴더는 단수 (`Model`, `Repository`, `Scene`)
5. 표준 컨테이너만 복수 (`Sources`, `Tests`)

### 7. Import / DI

허용:

| 모듈 | 허용 |
|---|---|
| Feature | Domain, SharedUtils, SharedDesignSystem, ThirdParty, ThirdPartyUI |
| Domain | SharedUtils, ThirdParty |
| Data | Domain, Core*, SharedUtils, ThirdPartyCore |
| Core | SharedUtils, ThirdPartyCore |
| App | 조립 only |

금지:

```text
Feature → Data / Core* / ThirdPartyCore
Domain  → Data / Core* / Feature
Data    → Feature
```

DI:

1. Feature 의존성은 Domain `*Client` 만
2. live 조립은 App DI only
3. bootstrap / Root store 는 `CompositionRoot` 1회
4. View / `WindowGroup` 안에서 store 생성 금지
5. Feature 코드에 `RepositoryImpl` / `ClientFactory` 이름 쓰지 않음
6. Data `*ClientFactory` 가 Domain client 반환
7. RepositoryImpl 은 Datasource 만 주입

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
force unwrap 금지
```

```text
test_세션없음_로그아웃상태복구
test_로그인성공_델리게이트_전달
```

```swift
withDependencies {
    $0.authClient.restoreSession = { nil }
    $0.authClient.login = { _ in
        AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userID: "demo"
        )
    }
}
```

규칙:

1. Feature 테스트에 Data/Core 구현을 끌어오지 않는다
2. Domain/Data 단위 테스트는 기본 강제 없음
3. 고위험 도메인만 보완 테스트 가능

### 10. 환경

| Scheme | Config | Bundle ID |
|---|---|---|
| `Dulpick-Debug` | Debug | `com.dulpick.debug` |
| `Dulpick` | Release | `com.dulpick.app` |

- storage namespace 는 Bundle ID 재사용
- Tuist: bundle id / display name / flags
- `Config/*.xcconfig`: API URL / secrets
- `AppInfo` 가 Info.plist 값을 읽음

### 11. 새 기능 체크

1. Domain `{Model,Error,Client}`
2. Data `{DTO,Datasource,RepositoryImpl,ClientFactory}`
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
```

- Type 은 commit type 과 동일
- jira key 는 소문자
- 작은 설정/문서만 `chore/no-issue` 가능

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

## d. 하지 말 것

- Feature 모듈 쪼개기
- AppShell / AppRuntime / AppEnvironment / AppConstants 재도입
- Feature → Data/Core 직접 참조
- Scene 간 직접 통신
- storage typed key 과설계
- 문서 주제별 과다 분리

관련:

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [../AGENTS.md](../AGENTS.md)
- [../.swiftlint.yml](../.swiftlint.yml)
