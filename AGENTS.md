# AGENTS

Dulpick 작업 시 에이전트 진입점.

이 파일은 Codex/에이전트가 구조를 깨지 않고 수정하기 위한 규칙이다.

---

## 1. 프로젝트 한 줄

```text
Tuist multi-project iOS 앱
세로 계층은 모듈, 가로 Feature는 폴더
TCA + Domain Client + App live 조립
```

---

## 2. 문서 우선순위

1. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
2. [docs/CONVENTIONS.md](docs/CONVENTIONS.md)
3. [AGENTS.md](AGENTS.md)
4. [CLAUDE.md](CLAUDE.md)  # AGENTS.md symlink

---

## 3. 확정된 구조

```text
Projects/
  Shared/{Util,DesignSystem}
  ThirdParty/{ThirdParty,ThirdPartyUI,ThirdPartyCore}
  Domain/
  Core/{Network,Storage,Logger}
  Data/
  Feature/
  App/
```

의존 방향:

```text
Feature → Domain, Shared*, ThirdParty, ThirdPartyUI
Data    → Domain, Core*, SharedLogger, SharedUtils
Domain  → SharedUtils, ThirdParty
App     → 조립 only
```

금지:

```text
Feature → Data / Core* / ThirdPartyCore
Domain  → Data / Core* / Feature
Data    → Feature
```

---

## 4. 현재 앱 흐름

```text
DulpickApp
  → CompositionRoot.makeRootStore()
      → AppBootstrap / InfraContainer / Dependencies
      → Store(RootFeature)
  → RootView
      → AppCoordinatorView
          phase:
            bootstrapping
            loggedOut(Auth)
            main(MainTab: Home/Explore/Map/MyPage)
```

핵심 이름:

- 앱 상태 머신: `AppCoordinator` (구 AppShell 아님)
- Domain 포트: `*Client`
- Data 구현: `*Repository` + `*ClientFactory`
- 설정 읽기: `AppInfo` → `AppConfiguration`

---

## 5. 반드시 지킬 규칙

1. Feature 모듈을 기능별로 쪼개지 않는다. 폴더로 나눈다.
2. Scene 간 직접 참조 금지. `delegate` 로 상위 전달.
3. live 조립은 App 만.
4. Feature 는 Domain `*Client` 만 사용.
5. Core/인프라 에러는 Data 에서 Domain 에러로 매핑.
6. 전역 에러(`sessionExpired` 등)만 AppCoordinator 로 승격.
7. 여러 Client 조합은 Feature/AppCoordinator 에서 처리한다.
8. storage namespace 는 Bundle ID 하나를 재사용한다.
9. 환경은 `debug` / `release` 두 개.
10. scheme:
    - `Dulpick-Debug` → Debug
    - `Dulpick` → Release

---

## 6. 새 기능 추가 순서

예: Wishlist

1. `Domain/Sources/Wishlist/{Model,Error,Client}`
2. `Data/Sources/Wishlist/{DTO,DataSource,Repository}`
   - `WishlistRepository`
   - `WishlistClientFactory`
3. `App/Sources/DI/Dependencies.swift` live 등록
4. `Feature/Sources/Scene/Wishlist/`
5. 필요 시 MainTab / DeepLink / AppCoordinator 연결
6. `Feature/Tests` reducer 테스트 (client override)

질문 순서:

1. 화면 흐름? → Feature
2. 서비스 계약? → Domain
3. 구현? → Data
4. 공용 인프라? → Core
5. 외부 SDK? → ThirdParty*
6. 조립? → App

---

## 7. 수정 시 주의

### 해도 되는 것

- Scene 추가/수정
- Domain client 메서드 확장
- Data 구현/매핑 추가
- App DI 등록 추가
- Feature 테스트 추가
- 문서 동기화

### 기본 금지 / 먼저 확인

- Feature 모듈 분리
- AppRuntime / AppEnvironment / AppConstants 재도입
- Feature → Data/Core 직접 참조
- Scene 간 직접 상태 수정
- Fastlane / stub network mode 재도입
- scheme/env 이름 임의 변경

---

## 8. 자주 쓰는 명령

```bash
mise install
mise exec -- tuist generate --no-open
open Dulpick.xcworkspace
```

빌드:

```bash
xcodebuild -workspace Dulpick.xcworkspace -scheme Dulpick-Debug -destination 'generic/platform=iOS Simulator' build
```

Feature 테스트:

```bash
DESTINATION="$(
  python3 - <<'PY'
import re
import subprocess

output = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available"],
    text=True,
)
for line in output.splitlines():
    match = re.search(r"iPhone.+?\(([A-F0-9-]{36})\)", line)
    if match:
        print(f"platform=iOS Simulator,id={match.group(1)}")
        break
else:
    raise SystemExit("No available iPhone simulator found")
PY
)"
xcodebuild -workspace Dulpick.xcworkspace -scheme Feature -destination "$DESTINATION" test
```

딥링크 확인:

```bash
xcrun simctl openurl booted "dulpick://home"
xcrun simctl openurl booted "dulpick://map"
```

---

## 9. 구식 명칭

보이면 현재 명칭으로 맞춘다.

- AppShell → AppCoordinator
- Repository 포트 → Client
- Dulpick-Prod → Dulpick

---

## 10. 완료 기준 감각

구조 관련 작업은 아래가 맞으면 통과다.

1. 의존 방향 유지
2. 기존 네이밍 컨벤션 유지
3. App live 조립 유지
4. Feature 테스트 가능
5. 문서와 코드 명칭 일치

---

## 11. Freeze

문서는 최소 세트만 유지한다.

```text
docs/ARCHITECTURE.md  # 구조 source of truth
docs/CONVENTIONS.md   # 코딩 규칙 한 장
AGENTS.md             # 에이전트 규칙
CLAUDE.md -> AGENTS.md
```

- 구조 변경 시 `docs/ARCHITECTURE.md`, 코딩 규칙 변경 시 `docs/CONVENTIONS.md` 동기화
- 기능 개발은 현재 확정 구조 위에서 진행
