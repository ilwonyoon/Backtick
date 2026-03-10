# Note Content Classification – Implementation Plan

## Overview

Stack 패널에 표시되는 카드 텍스트를 자동 분류(Path / Link / Secret / Plain)하고, 타입 라벨 + 상대 시간 표시 + 인터랙티브 텍스트 동작을 추가한다.

## Design Decisions

| 결정 | 근거 |
|------|------|
| 분류는 저장하지 않음 (computed) | DB 마이그레이션 불필요, text의 순수 함수 |
| 분류 시점: Stack 렌더링 시에만 | Capture 패널 성능 영향 zero |
| 캐시: CardStackView 레벨 `[UUID: ContentClassification]` | re-render 시 재계산 방지 |
| 우선순위: Secret > Link > Path | Secret이 URL 접두사를 포함할 수 있음 |

## Scope

### In Scope
- 텍스트 분류: Path, Link, Secret, Plain
- Stack 카드 UI: 타입 라벨 뱃지 + 상대 시간
- Secret 마스킹 (`sk-ant-a····9xQ2`)
- 감지된 텍스트 hover → underline + 커서 변경 (Link, Path만)
- 감지된 텍스트 click → Finder(Path) / 브라우저(Link)
- Secret: hover/click 없음, 마스킹만

### Out of Scope
- Capture 패널 (CaptureComposerView, CapturePanelRuntimeViewController) — 변경 없음
- DB 스키마 변경
- 멀티 매치 (v1은 primary match만)
- Windows 경로

---

## Phase 1: Core Classification Engine

> 위치: `Sources/PromptCueCore/` (순수 Swift, AppKit/SwiftUI 없음)

### 1.1 `ContentClassification.swift` — NEW

```swift
public enum ContentType: String, Sendable, Codable, CaseIterable {
    case path, link, secret, plain
}

public struct DetectedSpan: Equatable, Sendable {
    public let range: Range<String.Index>
    public let matchedText: String
    public let type: ContentType
}

public struct ContentClassification: Equatable, Sendable {
    public let primaryType: ContentType
    public let spans: [DetectedSpan]
    public let displayLabel: String  // "Path", "Link", "Secret", ""
    public static let plain = ContentClassification(...)
}
```

### 1.2 `ContentClassifier.swift` — NEW

순수 함수 `ContentClassifier.classify(_ text:) -> ContentClassification`

패턴 (우선순위 순):

| Type | Patterns |
|------|----------|
| Secret | `sk-ant-[A-Za-z0-9_-]{10,}`, `ghp_[A-Za-z0-9]{30,}`, `AKIA[A-Z0-9]{12,}`, `sk-live-[A-Za-z0-9_-]{10,}`, `sk-[A-Za-z0-9_-]{20,}`, `xoxb-[A-Za-z0-9-]+` |
| Link | `https?://[^\s]+` |
| Path | `~/[^\s]+`, `/[a-zA-Z][^\s]*(/[^\s]+)+`, `\./[^\s]+` |

### 1.3 `SecretMasker.swift` — NEW

```swift
public enum SecretMasker {
    public static func mask(_ text: String, visiblePrefix: Int = 8, visibleSuffix: Int = 4) -> String
    // "sk-ant-abc123xyz" → "sk-ant-a····xyz"
}
```

### 1.4 `RelativeTimeFormatter.swift` — NEW

```swift
public enum RelativeTimeFormatter {
    public static func string(for date: Date, relativeTo now: Date = Date()) -> String
    // <1min → "now", 1-59min → "3m ago", 1-23h → "1h ago", 1-6d → "2d ago", 7d+ → "1w ago"
}
```

---

## Phase 2: Core Unit Tests (TDD)

> 위치: `Tests/PromptCueCoreTests/`

### 2.1 `ContentClassifierTests.swift` — NEW

- Plain text → `.plain`
- `~/projects/foo` → `.path`
- `/usr/local/bin/thing` → `.path`
- `./relative/path` → `.path`
- `https://example.com` → `.link`
- `http://localhost:3000/api` → `.link`
- `sk-ant-abc123def456` → `.secret`
- `ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345` → `.secret`
- `AKIA1234567890AB` → `.secret`
- Secret > Link 우선순위 확인
- Empty / whitespace → `.plain`

### 2.2 `SecretMaskerTests.swift` — NEW

- 일반 마스킹 동작
- 짧은 문자열 처리
- Empty string

### 2.3 `RelativeTimeFormatterTests.swift` — NEW

- 0초 → "now"
- 3분 → "3m ago"
- 90분 → "1h ago"
- 25시간 → "1d ago"
- 미래 날짜 → "now"

### 검증 명령

```bash
swift test
```

---

## Phase 3: Design Token Extensions

### 3.1 `PrimitiveTokens.swift` — MODIFY

추가할 토큰:
- `FontSize.badge: CGFloat = 11`
- `Typography.badge: Font = .system(size: 11, weight: .medium)`
- `Radius.badge: CGFloat = 4`

### 3.2 `SemanticTokens.swift` — MODIFY

`Classification` sub-enum 추가:

| Token | Light | Dark |
|-------|-------|------|
| `pathBadgeBackground` | blue@10% | blue@14% |
| `pathBadgeText` | blue@80% | blue@70% |
| `linkBadgeBackground` | green@10% | green@14% |
| `linkBadgeText` | green@80% | green@70% |
| `secretBadgeBackground` | orange@10% | orange@14% |
| `secretBadgeText` | orange@80% | orange@70% |
| `linkHoverUnderline` | accent tint | accent tint |
| `pathHoverUnderline` | accent tint | accent tint |

---

## Phase 4: UI Components (Stack Only)

> Capture 패널은 변경하지 않음

### 4.1 `CardTypeBadge.swift` — NEW

`ContentType` → pill 형태 라벨. `.plain`이면 렌더 안함. ~40줄.

### 4.2 `InteractiveDetectedTextView.swift` — NEW

카드 텍스트를 3파트로 분리:
1. 감지 전 텍스트 (plain `Text`)
2. 감지된 span (`Button` wrapping, hover → underline + 색상)
3. 감지 후 텍스트 (plain `Text`)

| Type | Hover | Click |
|------|-------|-------|
| Link | underline + accent color | 브라우저 열기 |
| Path | underline + accent color | Finder 열기 |
| Secret | 없음 | 없음 |
| Plain | 없음 | 없음 |

Secret일 때는 `SecretMasker.mask(text)` 결과를 표시.

### 4.3 `CaptureCardView.swift` — MODIFY

변경 내용:
1. 메타데이터 행 추가: `CardTypeBadge` (좌) + 상대 시간 (우)
2. `Text(card.text)` → `InteractiveDetectedTextView` (classification이 `.plain`이 아닐 때)
3. `onDetectedTextAction` 클로저 추가

**변경하지 않는 것:**
- 복사/삭제 버튼
- Selection mode
- Overflow affordance
- CaptureComposerView / CapturePanelRuntimeViewController

### 4.4 `CardStackView.swift` — MODIFY

분류 캐시 추가:
```swift
@State private var classificationCache: [UUID: ContentClassification] = [:]
```

카드 렌더 시 캐시에서 조회, 없으면 계산 후 저장.

---

## Phase 5: Action Handlers

### 5.1 `CaptureCardView` 내 액션 — MODIFY

```swift
private func openDetectedContent(_ classification: ContentClassification) {
    switch classification.primaryType {
    case .link:
        guard let url = URL(string: span.matchedText) else { return }
        NSWorkspace.shared.open(url)
    case .path:
        let expanded = NSString(string: span.matchedText).expandingTildeInPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expanded)
    case .secret, .plain:
        break
    }
}
```

---

## Phase 6: Integration Tests

### 6.1 `ContentClassificationIntegrationTests.swift` — NEW

> 위치: `PromptCueTests/`

- URL 텍스트 카드 → Link 분류
- Secret 텍스트 카드 → 마스킹된 표시 텍스트
- Plain 텍스트 카드 → 뱃지 없음
- 상대 시간 포맷 확인

### 검증 명령

```bash
xcodegen generate
xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

---

## Phase 7: Polish & Edge Cases

- 멀티 매치: v1은 primary만, v2에서 모든 span 하이라이트
- 긴 URL/경로: 텍스트 표시는 그대로, 클릭 시 전체 값 사용
- `~/` 경로: `NSString.expandingTildeInPath` 처리
- 성능: 50+ 카드 프로파일링 → 캐시로 충분할 것으로 예상

---

## File Summary

### New Files (10)

| File | Location |
|------|----------|
| `ContentClassification.swift` | `Sources/PromptCueCore/` |
| `ContentClassifier.swift` | `Sources/PromptCueCore/` |
| `SecretMasker.swift` | `Sources/PromptCueCore/` |
| `RelativeTimeFormatter.swift` | `Sources/PromptCueCore/` |
| `ContentClassifierTests.swift` | `Tests/PromptCueCoreTests/` |
| `SecretMaskerTests.swift` | `Tests/PromptCueCoreTests/` |
| `RelativeTimeFormatterTests.swift` | `Tests/PromptCueCoreTests/` |
| `CardTypeBadge.swift` | `PromptCue/UI/Views/` |
| `InteractiveDetectedTextView.swift` | `PromptCue/UI/Views/` |
| `ContentClassificationIntegrationTests.swift` | `PromptCueTests/` |

### Modified Files (4)

| File | Changes |
|------|---------|
| `PrimitiveTokens.swift` | badge 토큰 추가 |
| `SemanticTokens.swift` | Classification 색상 추가 |
| `CaptureCardView.swift` | 메타데이터 행, 인터랙티브 텍스트, 액션 핸들러 |
| `CardStackView.swift` | 분류 캐시 |

---

## Success Criteria

- [ ] `swift test` — Core 테스트 전체 통과
- [ ] `xcodebuild test` — App 테스트 전체 통과
- [ ] Link 카드: "Link" 뱃지 + 텍스트 hover→underline + click→브라우저
- [ ] Path 카드: "Path" 뱃지 + 텍스트 hover→underline + click→Finder
- [ ] Secret 카드: "Secret" 뱃지 + 마스킹 + hover/click 없음
- [ ] Plain 카드: 뱃지 없음 (기존과 동일)
- [ ] 상대 시간 모든 카드에 표시
- [ ] Capture 패널 변경 없음
- [ ] 토큰 시스템 준수 (하드코딩 없음)
- [ ] DB 마이그레이션 없음
