# AGENTS

Dulpick 작업 시 에이전트 진입점.

---

## 어디를 보나

| 질문 | 문서 |
|---|---|
| 모듈·의존·앱 흐름 | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 코딩·Git 규칙 | [docs/CONVENTIONS.md](docs/CONVENTIONS.md) |
| 포맷·안전성 | [.swiftlint.yml](.swiftlint.yml) |
| 리뷰 기준 | [.coderabbit.yaml](.coderabbit.yaml) |

---

## 절대 규칙

1. Feature 는 단일 모듈. 기능은 폴더로 나눈다
2. Scene 간 직접 참조 금지. `delegate` 로 상위에 올린다
3. Feature 는 Domain `*Client` 만 쓴다
4. Domain `*Client` live 등록은 App 만 한다. 외부 SDK 초기화는 SDK 를 소유한 모듈이 Bootstrap 타입으로 갖고, App 은 호출만 한다
5. Core/인프라 에러는 Data 에서 Domain 에러로 매핑한다
6. 전역 에러(`sessionExpired` 등)만 AppCoordinator 로 승격한다

---

## 먼저 물을 것

- Feature 모듈 분리
- Feature → Data/Core 직접 참조
- scheme/환경 이름 변경
- 문서 추가·분리

---

## 자주 쓰는 명령

```bash
mise install && mise exec -- tuist generate --no-open

xcodebuild -workspace Dulpick.xcworkspace -scheme Dulpick-Debug \
  -destination 'generic/platform=iOS Simulator' build

xcodebuild -workspace Dulpick.xcworkspace -scheme Feature \
  -destination 'platform=iOS Simulator,name=iPhone 14' test
# 이름이 없으면: xcrun simctl list devices available | grep iPhone

xcrun simctl openurl booted "dulpick://home"
```
