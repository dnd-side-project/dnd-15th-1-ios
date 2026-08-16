# Dulpick Architecture

중대형 iOS 앱 기준 아키텍처.

```text
세로 계층 = 모듈
가로 Feature = 폴더
외부 의존성 = ThirdParty*
Domain *Client live 등록 = App only
외부 SDK 초기화 = 소유 모듈의 Bootstrap 타입, App 은 호출만
```

---

## 1. 모듈

```text
Projects/
  Shared/{Util,DesignSystem,Logger}   # SharedUtils, SharedDesignSystem, SharedLogger
  ThirdParty/{ThirdParty,ThirdPartyUI,ThirdPartyCore}
  Domain/
  Core/{Network,Storage}              # CoreNetwork, CoreStorage
  Data/
  Feature/
  App/
```

| 모듈 | 책임 |
|---|---|
| SharedUtils | `AppInfo` 등 순수 공통 코드 |
| SharedDesignSystem | UI 토큰/컴포넌트 |
| SharedLogger | 전 계층 공통 OSLog facade. Feature 는 `Reducer.logged(as:)` 로 Action/State/Navigation/Error 자동 로그 |
| ThirdParty* | 외부 패키지 진입점. ThirdPartyCore = Alamofire + 소셜 SDK 입구 |
| Domain | Entity, `*Client`, Error |
| Core/* | Network/Storage |
| Data | DTO, DataSource, `*Repository`, `*ClientFactory` |
| Feature | Root, AppCoordinator, MainTab, Scene |
| App | bootstrap, live 주입, root store |

### 의존

```text
Feature → Domain, SharedUtils, SharedDesignSystem, SharedLogger, ThirdParty, ThirdPartyUI
Data    → Domain, Core/*, SharedLogger, SharedUtils
Domain  → SharedUtils, ThirdParty
Core/*  → SharedUtils, SharedLogger, ThirdPartyCore
App     → 조립
```

### 금지

```text
Feature → Data / Core* / ThirdPartyCore
Domain  → Data / Core* / Feature
Data    → Feature
```

---

## 2. 런타임

```text
DulpickApp
  → CompositionRoot.makeRootStore()
      → AppBootstrap
          → InfraContainer.make()      # AppInfo/AppConfiguration
          → Dependencies.register      # Data.*ClientFactory
      → Store(RootFeature)
  → RootView → AppCoordinatorView
```

앱 상태:

```text
bootstrapping
  → authClient.restoreSession()
  → session 있음: main(...)
  → session 없음 + !hasSeenAppIntro: appIntro
  → session 없음 + hasSeenAppIntro: loggedOut(Auth)

appIntro enter
  → markAppIntroSeen()
appIntro complete
  → loggedOut(Auth)
```

---

## 3. Feature

단일 모듈. 기능은 폴더로 나눈다.

규칙:

1. 화면은 `Scene/<이름>/`, 그 안은 flat (`*Feature`, `*View`)
2. Scene 간 직접 참조 금지
3. 외부 요청은 `delegate` 로 AppCoordinator/MainTab 상승
4. Feature 는 Domain `*Client` 만 사용
5. 전역 전환·딥링크·overlay 는 `AppCoordinator/` 아래 (`MainTab`, `DeepLink`, `Overlay`)
6. 공용 코드는 `Extension`(타입 확장) 과 `Util`(주제 폴더) 로 나눈다.
   `Util/` 바로 아래에 파일을 두지 않는다 — 반드시 주제 폴더를 만든다

네비게이션:

```text
phase(AppCoordinator) → tab(MainTab) → scene local → overlay
```

딥링크:

```text
URL → DeepLinkRouter → DeepLinkRoute → AppCoordinator
bootstrapping / appIntro / loggedOut 이면 pending, 로그인 후 flush
appIntro / loggedOut 은 home|explore|map|myPage 만 pending, signIn 은 무시
```

---

## 4. Domain / Data

새 기능을 만들 때 어떤 폴더를 두는지는 [CONVENTIONS.md](CONVENTIONS.md) §10 을 본다.

규칙:

1. Domain `*Client` = 포트
2. Data `*Repository` = 구현
3. Data `*ClientFactory` = Domain client 생성
4. Repository 는 기본적으로 DataSource 만 주입. SDK credential provider 등은 `Service` collaborator 허용
5. DataSource 프로퍼티는 `authLocal`, `authRemote`
6. Core/인프라 에러는 Data 에서 Domain 에러로 매핑
7. 여러 Client 조합은 Feature/AppCoordinator 에서 처리

---

## 5. App / Config

설정:

```text
Tuist settings  → bundle id, display name, flags
Config/*.xcconfig → API_BASE_URL, secrets
Info.plist → AppInfo → AppConfiguration → InfraContainer
```

| Scheme | Config | Bundle ID |
|---|---|---|
| `Dulpick-Debug` | Debug | `com.dulpick.debug` |
| `Dulpick` | Release | `com.dulpick.app` |

storage namespace 는 Bundle ID 하나 재사용.

---

## 6. 관련

- [CONVENTIONS.md](CONVENTIONS.md)
- [../AGENTS.md](../AGENTS.md)
- [../CLAUDE.md](../CLAUDE.md) (`AGENTS.md` symlink)

네이밍·새 기능 순서·테스트 규칙·DesignSystem 판정은 [CONVENTIONS.md](CONVENTIONS.md) 를 본다.

구조는 이 파일, 코딩 규칙은 `CONVENTIONS.md` 가 source of truth 다.
