# Dulpick Architecture

중대형 iOS 앱 기준 아키텍처.

```text
세로 계층 = 모듈
가로 Feature = 폴더
외부 의존성 = ThirdParty*
live 조립 = App only
```

---

## 1. 모듈

```text
Projects/
  Shared/{Util,DesignSystem}          # SharedUtils, SharedDesignSystem
  ThirdParty/{ThirdParty,ThirdPartyUI,ThirdPartyCore}
  Domain/
  Core/{Network,Storage,Logger}       # CoreNetwork, CoreStorage, CoreLogger
  Data/
  Feature/
  App/
```

| 모듈 | 책임 |
|---|---|
| SharedUtils | `AppInfo` 등 순수 공통 코드 |
| SharedDesignSystem | UI 토큰/컴포넌트 |
| ThirdParty* | 외부 패키지 진입점 |
| Domain | Entity, `*Client`, Error |
| Core/* | Network/Storage/Logger |
| Data | DTO, Datasource, `*RepositoryImpl`, `*ClientFactory` |
| Feature | Root, AppCoordinator, MainTab, Scene |
| App | bootstrap, live 주입, root store |

### 의존

```text
Feature → Domain, SharedUtils, SharedDesignSystem, ThirdParty, ThirdPartyUI
Data    → Domain, Core/*, SharedUtils
Domain  → SharedUtils, ThirdParty
Core/*  → SharedUtils, ThirdPartyCore
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
          → InfraContainer.live()      # AppInfo/AppConfiguration
          → Dependencies.register      # Data.*ClientFactory
      → Store(RootFeature)
  → RootView → AppCoordinatorView
```

앱 상태:

```text
bootstrapping
  → authClient.restoreSession()
  → main(Home/Explore/Map/MyPage) 또는 loggedOut(Auth)
```

현재 세션 복구는 로컬 조회 중심. refresh/401 interceptor 는 아직 없음.

---

## 3. Feature

단일 모듈. 기능은 폴더로 나눈다.

```text
Feature/Sources/
  Root/
  AppCoordinator/
    MainTab/
    DeepLink/
    Overlay/
  Common/
  Scene/{Auth,Home,Explore,Map,MyPage}
```

규칙:

1. Scene 안은 flat (`*Feature`, `*View`)
2. Scene 간 직접 참조 금지
3. 외부 요청은 `delegate` 로 AppCoordinator/MainTab 상승
4. Feature 는 Domain `*Client` 만 사용
5. 전역 전환/딥링크/overlay 는 AppCoordinator

네비게이션:

```text
phase(AppCoordinator) → tab(MainTab) → scene local → overlay
```

딥링크:

```text
URL → DeepLinkRouter → DeepLinkRoute → AppCoordinator
bootstrapping/loggedOut 이면 pending, 로그인 후 flush
```

현재:

```text
dulpick://home|explore|map|mypage|auth/sign-in
```

---

## 4. Domain / Data

```text
Domain/<Name>/{Model,Client,Error}
Data/<Name>/{DTO,Datasource,Repository}
  *RepositoryImpl
  *ClientFactory
```

규칙:

1. Domain `*Client` = 포트
2. Data `*RepositoryImpl` = 구현
3. Data `*ClientFactory` = Domain client 생성
4. RepositoryImpl 은 Datasource 만 주입
5. Datasource 프로퍼티는 `authLocal`, `authRemote`
6. Core/인프라 에러는 Data 에서 Domain 에러로 매핑
7. 여러 Client 조합은 Feature/AppCoordinator 에서 처리

---

## 5. App / Config

```text
App/Sources/
  DulpickApp.swift
  CompositionRoot.swift
  DI/
    AppBootstrap.swift
    AppConfiguration.swift
    InfraContainer.swift
    Dependencies.swift
```

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

## 6. 네이밍

| 계층 | 패턴 | 예 |
|---|---|---|
| Domain client | `*Client` | `AuthClient` |
| Data impl | `*RepositoryImpl` | `AuthRepositoryImpl` |
| Data factory | `*ClientFactory` | `AuthClientFactory` |
| Feature | `*Feature` / `*View` | `HomeFeature` |

모듈 prefix:

```text
CoreNetwork, SharedUtils, ThirdPartyUI ...
```

---

## 7. 새 기능

1. Domain `{Model,Error,Client}`
2. Data `{DTO,Datasource,RepositoryImpl,ClientFactory}`
3. App `Dependencies.register`
4. Feature `Scene/<Name>`
5. 필요 시 AppCoordinator/MainTab/DeepLink
6. Feature 테스트 (client override)

질문:

```text
화면? Feature
계약? Domain
구현? Data
인프라? Core
외부 SDK? ThirdParty*
조립? App
```

---

## 8. 테스트 / 분리

테스트:

- 기본: Feature reducer 테스트
- mock: Domain `*Client` override
- Domain/Data 테스트는 기본 강제 없음

지금은 하지 않음:

- Feature 모듈 쪼개기
- Micro feature multi-project

분리 검토 시점:

- Feature 빌드 병목
- 기능 단위 소유권 분리
- Core 독립 교체 필요

---

## 9. 관련

- [CONVENTIONS.md](CONVENTIONS.md)
- [../AGENTS.md](../AGENTS.md)
- [../CLAUDE.md](../CLAUDE.md) (`AGENTS.md` symlink)

구조는 이 파일, 코딩 규칙은 `CONVENTIONS.md` 가 source of truth 다.
