# Architecture Cleanup Plan

## 상황

main에서 Settings 디자인 시스템 리팩토링 머지 진행 중 (`de7f068`).
이 브랜치는 main 안정화 후 리베이스해서 머지할 예정.

**원칙:**
- main에서 활발히 수정 중인 파일은 건드리지 않음
- extension 추출 패턴으로 API 변경 없이 파일만 분리
- 각 Phase는 독립 커밋, Phase 단위로 빌드+테스트 확인
- 충돌 최소화를 위해 main과 겹치지 않는 파일부터 진행

---

## 전체 현황 (400줄 초과 파일)

| 파일 | 줄 | 판정 | main 수정 중 | 우선순위 |
|------|-----|------|-------------|---------|
| `PromptCueSettingsView.swift` | 1702 | SPLIT | **YES** | Phase 3 (main 안정화 후) |
| `AppModel.swift` | 1340 | SPLIT | no | **Phase 1** |
| `MCPConnectorSettingsModel.swift` | 1251 | OK | YES | 건드리지 않음 |
| `CapturePanelRuntimeVC.swift` | 977 | OK | no | 경미 (Phase 4) |
| `CapturePanelController.swift` | 852 | OK | no | 경미 (Phase 4) |
| `DesignSystemPreviewView.swift` | 799 | OK | YES | 건드리지 않음 |
| `RecentScreenshotCoordinator.swift` | 750 | SPLIT | no | **Phase 2** |
| `BacktickMCPServerSession.swift` | 727 | OK | no | 건드리지 않음 |
| `CaptureSuggestedTargetViews.swift` | 675 | 경미 | no | Phase 4 |
| `RecentSuggestedAppTargetTracker.swift` | 648 | SPLIT | no | **Phase 2** |

---

## Phase 1: AppModel 분해 (main과 충돌 없음)

**현재**: 1340줄, 8개 도메인이 혼재
**목표**: 핵심 카드 CRUD만 남기고 나머지 추출

### 추출 대상

| 추출 파일 | 현재 위치 | 내용 | 예상 줄 |
|-----------|----------|------|---------|
| `AppModel+CaptureSession.swift` | AppModel 내 | 캡처 세션 시작/종료, 드래프트 관리, 제출 플로우 | ~200 |
| `AppModel+SuggestedTarget.swift` | AppModel 내 | 타겟 추적, 선택, chooser 상태 | ~150 |
| `AppModel+CloudSync.swift` | AppModel 내 | CloudKit 머지, 리모트 적용, 충돌 해결 | ~250 |
| `AppModel+Screenshot.swift` | AppModel 내 | 스크린샷 감지 상태, 프리뷰, 소비 | ~150 |
| `AppModel.swift` (남는 것) | — | 카드 CRUD, init, 공유 상태, export | ~400 |

### 추출 패턴

```swift
// AppModel+CaptureSession.swift
extension AppModel {
    func beginCaptureSession() { ... }
    func submitCapture() async throws { ... }
    func cancelCapture() { ... }
    // ... capture session 관련 모든 메서드
}
```

`@Published` 프로퍼티는 AppModel.swift에 남기고, 메서드만 extension으로 이동.
이렇게 하면 프로퍼티 선언은 한 곳, 로직은 도메인별 파일로 분산.

### 실행

1. AppModel.swift 읽고 도메인별 메서드 목록 작성
2. `AppModel+CaptureSession.swift` 추출 → 빌드 확인
3. `AppModel+SuggestedTarget.swift` 추출 → 빌드 확인
4. `AppModel+CloudSync.swift` 추출 → 빌드 확인
5. `AppModel+Screenshot.swift` 추출 → 빌드 확인
6. 커밋: `refactor: extract AppModel domains into extensions`

---

## Phase 2: Services 분해 (main과 충돌 없음)

### RecentSuggestedAppTargetTracker.swift (648줄)

| 추출 파일 | 내용 | 예상 줄 |
|-----------|------|---------|
| `TerminalWindowSnapshotProvider.swift` | Terminal/iTerm 윈도우 열거 + AppleScript 파싱 | ~180 |
| `IDEWindowSnapshotProvider.swift` | VS Code/Xcode 윈도우 열거 | ~80 |
| `TargetDetailResolver.swift` | git branch, CWD 등 상세 정보 해석 | ~140 |
| `RecentSuggestedAppTargetTracker.swift` (남는 것) | 퍼사드: start/stop, 현재 타겟, 가용 목록 | ~250 |

### RecentScreenshotCoordinator.swift (750줄)

| 추출 파일 | 내용 | 예상 줄 |
|-----------|------|---------|
| `ScreenshotScanResultHandler.swift` | 스캔 결과 → 상태 전환 적용 | ~100 |
| `RecentScreenshotCoordinator.swift` (남는 것) | 상태머신, 타이머, 세션 관리 | ~650 |

> 클립보드 모니터링은 이미 `RecentClipboardImageMonitor.swift`로 분리되어 있음.
> 스캔 결과 핸들러만 추출하면 충분.

### 실행

7. TargetTracker 도메인별 메서드 분류
8. `TerminalWindowSnapshotProvider.swift` 추출 → 빌드 확인
9. `IDEWindowSnapshotProvider.swift` 추출 → 빌드 확인
10. `TargetDetailResolver.swift` 추출 → 빌드 확인
11. 커밋: `refactor: extract target tracker providers`
12. `ScreenshotScanResultHandler.swift` 추출 → 빌드 확인
13. 커밋: `refactor: extract screenshot scan result handler`

---

## Phase 3: PromptCueSettingsView 분해 (main 안정화 후 리베이스)

**이 Phase는 main의 Settings 리팩토링 머지가 끝난 후 리베이스해서 진행.**

기존 `docs/Settings-View-Decomposition-Plan.md`의 Phase 1~4 그대로 실행:

14. 미사용 코드 삭제 (`connectorSection` ~193줄)
15. 커밋: `chore: remove unused connector section views`
16. 탭 뷰 추출 (General, Capture, Stack)
17. 커밋: `refactor: extract settings tab views`
18. 커넥터 분리 (ConnectorSettingsTab + 3개 시트)
19. 커밋: `refactor: extract connector settings and sheets`
20. 공통 헬퍼 정리
21. 커밋: `refactor: move shared settings helpers to components`

---

## Phase 4: 경미한 추출 (선택)

| 파일 | 추출 대상 | 줄 |
|------|----------|-----|
| `CapturePanelRuntimeVC.swift` | `CapturePreviewImageCache` → 별도 파일 | ~46 |
| `CapturePanelController.swift` | SuggestedTarget 패널 뷰 3개 → 별도 파일 | ~200 |
| `CaptureSuggestedTargetViews.swift` | `SuggestedTargetIconProvider` → 별도 파일 | ~27 |

이 Phase는 급하지 않음. 해당 파일을 수정할 일이 생길 때 같이 진행.

---

## 충돌 위험 매트릭스

| Phase | 건드리는 파일 | main 수정 중? | 충돌 위험 |
|-------|-------------|-------------|----------|
| Phase 1 | `AppModel.swift` | no | **안전** |
| Phase 2 | `RecentSuggestedAppTargetTracker.swift`, `RecentScreenshotCoordinator.swift` | no | **안전** |
| Phase 3 | `PromptCueSettingsView.swift` | **YES** | **리베이스 후 진행** |
| Phase 4 | `CapturePanelRuntimeVC.swift`, `CapturePanelController.swift` | no | **안전** |

---

## 검증 기준

각 커밋마다:
- [ ] `xcodegen generate` 성공
- [ ] `swift test` 통과
- [ ] `xcodebuild build` 성공 (`CODE_SIGNING_ALLOWED=NO`)
- [ ] `xcodebuild test` 기존 테스트 전부 통과
- [ ] 추출 전후 public API 변경 없음

## 리베이스 전략

```
main (Settings 리팩토링 머지 완료)
  ↑
architecture-cleanup (Phase 1~2 완료)
  → git rebase main
  → Phase 3 진행
  → PR 생성
```

Phase 1~2는 main과 충돌 없는 파일만 건드리므로 리베이스 시 충돌 없음.
Phase 3는 리베이스 후 최신 `PromptCueSettingsView.swift` 기준으로 작업.
