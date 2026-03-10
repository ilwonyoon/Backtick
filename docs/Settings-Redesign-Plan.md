# Settings Redesign — Implementation Plan

## Problem
현재 Settings는 5개 섹션이 하나의 ScrollView에 나열됨. 어떤 기능이 있는지 한눈에 안 보이고, 스크롤해야 발견되는 기능이 있음 (특히 AI Export Tail).

## Design Decision
**Toolbar 탭바** 패턴 채택 (macOS 전통 Preferences 스타일).

- 3개 탭 — 아이콘 + 레이블로 상단 toolbar에 배치
- 탭 선택 시 해당 섹션 내용만 표시 (스크롤 불필요하거나 최소화)
- `NSWindow.toolbarStyle = .preference` 활용 (현재 이미 설정됨)

## Tab Structure

| # | Tab | SF Symbol | 포함 내용 |
|---|-----|-----------|-----------|
| 1 | **General** | `gearshape` | Appearance (다크/라이트/오토), Shortcuts, iCloud Sync |
| 2 | **Capture** | `rectangle.and.pencil.and.ellipsis` | Screenshots, App Selector (on/off, 추후 구현) |
| 3 | **Stack** | `square.stack.3d.up` | Retention (auto-expire), AI Export Tail |

### Why 3 tabs
- General: 앱 전반 설정 (외형 + 단축키 + 동기화)
- Capture: 캡쳐 입력 관련 (스크린샷 소스 + 앱 대상 선택)
- Stack: 스택 카드 출력 관련 (보존 정책 + 내보내기 꼬리말)

### New: Appearance row (General에 추가)
- Picker: Auto / Light / Dark
- `NSApp.appearance = NSAppearance(named:)` 로 적용
- UserDefaults key: `appearance.mode`

### Future: App Selector row (Capture에 추가 예정)
- Toggle: Enable app detection (default: on)
- 구현 시점은 Working with Apps 기능 완성 후

## Layout

```
Window:          560 x 460 (fixed, not resizable)
Toolbar:         macOS native NSToolbar with .preference style
Tab content:     전체 윈도우 영역, 각 탭별 padding(24)
```

### Toolbar 구현
- `NSToolbar` + `NSToolbarItem` 3개 (icon + label)
- `NSToolbarItem.Identifier`: `.general`, `.capture`, `.stack`
- `toolbarStyle = .preference` → 자동으로 탭 선택 스타일 적용
- `selectedToolbarItemIdentifier`로 탭 상태 관리

### PanelMetrics updates
```swift
settingsPanelWidth:  560 (유지)
settingsPanelHeight: 620 → 460  // 각 탭이 짧아지므로 높이 감소
```

## Implementation Phases

### Phase 1: Toolbar 탭 navigation
**Files:** `SettingsWindowController.swift`, `PromptCueSettingsView.swift`, `PanelMetrics.swift`

1. `SettingsTab` enum: `.general`, `.capture`, `.stack`
   - `title: String`, `icon: String` (SF Symbol name), `toolbarIdentifier`
2. `SettingsWindowController`에 `NSToolbar` 설정:
   - 3개 `NSToolbarItem` 생성 (SF Symbol + 레이블)
   - `toolbarSelectableItemIdentifiers` 반환
   - `selectedToolbarItemIdentifier` 바인딩
   - 탭 변경 시 `contentViewController` 교체 또는 SwiftUI `@State` 연동
3. `PromptCueSettingsView`에 `selectedTab` 받아서 `switch`로 탭 내용 분기
4. PanelMetrics 높이 업데이트
5. 윈도우 사이즈를 탭별로 동적 조정 (내용 높이에 맞춤)

### Phase 2: Section content extraction
**Files:** `PromptCueSettingsView.swift`

1. 기존 `settingsSection` 블록들을 각 탭별 `@ViewBuilder` 함수로 분리:
   - `generalContent` — Appearance + Shortcuts + iCloud Sync
   - `captureContent` — Screenshots (+ 추후 App Selector)
   - `stackContent` — Retention + AI Export Tail
2. `sectionDivider` 유지 (탭 내에서 서브섹션 구분용)
3. 각 탭 내용은 ScrollView wrapping (Stack 탭의 Export Tail 에디터가 길 수 있음)

### Phase 3: Appearance setting (General 탭에 추가)
**New files:** `AppearanceSettingsModel.swift`

1. `AppearanceMode` enum: `.auto`, `.light`, `.dark`
2. `AppearancePreferences`: UserDefaults load/save
3. `AppearanceSettingsModel`: ObservableObject
4. General 탭 최상단에 Appearance Picker 행 추가
5. `NSApp.appearance` 적용 로직 (앱 시작 시 + 변경 시)
6. SettingsWindowController / AppCoordinator에 model 주입

### Phase 4: Polish
1. 탭 전환 시 윈도우 높이 애니메이션 (내용에 맞게 자연스럽게 리사이즈)
2. 접근성 라벨
3. QA 환경 플래그: `PROMPTCUE_OPEN_SETTINGS_ON_START=1`

## File Change Summary

| File | Change |
|------|--------|
| `PromptCueSettingsView.swift` | 탭별 content 분리, selectedTab switch 구조로 재작성 |
| `SettingsWindowController.swift` | NSToolbar 추가, 탭 전환 로직, 동적 윈도우 사이즈 |
| `PanelMetrics.swift` | 윈도우 높이 업데이트 |
| `AppearanceSettingsModel.swift` | **신규** — Appearance 설정 모델 |
| `AppCoordinator.swift` | AppearanceSettingsModel 생성/주입 |

## Phase 0: Copy Reduction (텍스트 다이어트)

현재 Settings의 텍스트가 과도함. 섹션 footer, rowNote, 상세 설명이 구구절절하여 핵심이 묻힘.
모든 설명 텍스트를 **토글/컨트롤 자체로 의미가 전달되면 삭제**, 꼭 필요한 것만 짧게 유지.

### 삭제/축소 대상

| 현재 텍스트 | 위치 | 조치 | 이유 |
|------------|------|------|------|
| `"These shortcuts work globally."` | Shortcuts footer | **삭제** | 단축키가 글로벌인 건 자명 |
| `"Cards stay until you delete them unless auto-expire is enabled."` | Retention footer | **삭제** | 토글 레이블로 충분 |
| `"Off by default. Turn this on to restore the original 8-hour cleanup behavior."` | Retention rowNote | **삭제** | 토글이 꺼져있으면 자명 |
| `"Auto-expire stack cards after 8 hours"` | Retention toggle | → `"Auto-expire after 8 hours"` | 축소 |
| `"Saved cards stay unchanged. The tail is added only when you copy or export."` | Export Tail footer | **삭제** | 토글 레이블로 충분 |
| `"Append your reusable instruction block to copied text without modifying saved cards."` | Export Tail rowNote | → `"Added to clipboard output only"` | 한 줄로 축소 |
| `"Auto-attach only checks the screenshot folder you explicitly approve."` | Screenshots footer | **삭제** | 폴더 선택 UX로 충분 |
| `"System screenshots often save to ~/Desktop. Choose that folder to enable auto-attach."` | Screenshots detail (notConfigured) | → `"Choose your screenshot folder."` | 핵심만 |
| `"Backtick remembers X, but access needs to be approved again."` | Screenshots detail (needsReconnect) | → `"Access expired. Reconnect to continue."` | 축소 |
| `"Sync cards across your Macs via iCloud. Screenshots stay local."` | iCloud Sync footer | → `"Screenshots stay local."` | 핵심 주의사항만 |
| `"Cards sync automatically between Macs signed into the same Apple ID."` | iCloud Sync rowNote | **삭제** | 토글 레이블로 충분 |

### Before / After 비교

**Before (Retention 섹션):**
```
Retention
Cards stay until you delete them unless auto-expire is enabled.

Card Lifetime    ☑ Auto-expire stack cards after 8 hours
                 Off by default. Turn this on to restore the
                 original 8-hour cleanup behavior.
```

**After:**
```
Card Lifetime    ☑ Auto-expire after 8 hours
```

**Before (iCloud Sync 섹션):**
```
iCloud Sync
Sync cards across your Macs via iCloud. Screenshots stay local.

Sync      ☑ Enable iCloud sync
          Cards sync automatically between Macs signed into
          the same Apple ID.
Status    Last synced 2 min ago
```

**After:**
```
iCloud Sync    ☑ Enable iCloud sync
               Screenshots stay local.
Status         Last synced 2 min ago
```

### 원칙
1. **토글/컨트롤의 레이블이 행동을 설명하면 추가 텍스트 불필요**
2. **Footer는 주의사항이 있을 때만** (예: "Screenshots stay local")
3. **rowNote는 동작이 비직관적일 때만** (예: export tail이 저장된 카드는 안 건드린다는 점)
4. **상태 텍스트(Status)는 유지** — 현재 상태를 보여주는 건 필요

## NOT in scope
- 검색 기능
- 탭 내 세부 네비게이션 (섹션 수가 적으므로 불필요)
- App Selector 기능 구현 (Capture 탭에 자리만 확보)
