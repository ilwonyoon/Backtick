# Settings View Decomposition Plan

## 문제

`PromptCueSettingsView.swift` 1699줄에 4개 탭 뷰, 3개 시트, 커넥터 UI, 헬퍼가 전부 들어있음.
Settings 관련 노트를 병렬 작업하려면 파일 단위로 분리되어야 충돌 없이 진행 가능.

**모델은 이미 잘 분리됨** — 뷰만 분해하면 됨.

---

## 현재 구조

```
PromptCueSettingsView.swift (1699줄)
├── 메인 컨테이너 + 사이드바 + 라우터           ~120줄
├── generalSections (Appearance, Shortcuts, iCloud) ~80줄
├── captureSections (Screenshot)                    ~45줄
├── stackSections (Retention, Export Tail)          ~80줄
├── connectorsContent + focusedConnectorRow         ~370줄
├── connectorSetupSheet                             ~92줄
├── connectorAlternateSetupSheet                    ~76줄
├── connectorInstallSheet                           ~35줄
├── connectorSection + missingCLIConnectorSection   ~193줄 ← 미사용
├── 가시성 헬퍼 (shouldShow*, is*Expanded)          ~45줄
├── UI 컴포넌트 (badges, advancedValueBlock 등)     ~220줄
└── 유틸리티 (binding, ConnectorChipTone)           ~60줄
```

---

## 목표 구조

```
PromptCueSettingsView.swift (~250줄)
├── 프로퍼티, init
├── body (NavigationSplitView)
├── settingsSidebar
├── settingsContentPane + selectedTabContent (라우터)
├── settingsScrollPage (공통 레이아웃)
└── settingsPageHeader

GeneralSettingsTab.swift (~80줄)
├── generalSections
└── appearance, shortcuts, iCloud sync 섹션

CaptureSettingsTab.swift (~80줄)
├── captureSections
└── screenshot 상태/버튼, 헬퍼 (screenshotStatusTitle 등)

StackSettingsTab.swift (~80줄)
├── stackSections
└── retention, export tail 섹션

ConnectorSettingsTab.swift (~400줄)
├── connectorsContent
├── focusedConnectorRow + 관련 헬퍼
├── connectorClientBadge
├── 가시성 헬퍼 (shouldShow*, is*Expanded)
└── ConnectorChipTone enum

ConnectorSetupSheet.swift (~110줄)
├── connectorSetupSheet
├── showSetupCommandCopiedFeedback
└── advancedValueBlock (코드 블록 표시)

ConnectorAlternateSetupSheet.swift (~90줄)
├── connectorAlternateSetupSheet
├── showConfigSnippetCopiedFeedback
└── advancedMessageBlock

ConnectorInstallSheet.swift (~40줄)
└── connectorInstallSheet
```

---

## 실행 단계

### Phase 1: 정리 (충돌 최소)

1. **미사용 코드 삭제** — `connectorSection` (~193줄), `missingCLIConnectorSection` 제거
2. **빌드 + 테스트 확인**
3. 커밋

### Phase 2: 탭 뷰 추출

각 탭을 별도 파일의 `private extension PromptCueSettingsView`로 추출.
이렇게 하면 init 시그니처 변경 없이 파일만 분리됨.

4. `GeneralSettingsTab.swift` — `generalSections` + `generalPage` 이동
5. `CaptureSettingsTab.swift` — `captureSections` + `capturePage` + screenshot 헬퍼 이동
6. `StackSettingsTab.swift` — `stackSections` + `stackPage` 이동
7. **빌드 + 테스트 확인**
8. 커밋

### Phase 3: 커넥터 분리

9. `ConnectorSettingsTab.swift` — connectorsContent, focusedConnectorRow, 가시성 헬퍼, ChipTone 이동
10. `ConnectorSetupSheet.swift` — connectorSetupSheet + handleConnectorPrimaryAction 이동
11. `ConnectorAlternateSetupSheet.swift` — connectorAlternateSetupSheet 이동
12. `ConnectorInstallSheet.swift` — connectorInstallSheet 이동
13. **빌드 + 테스트 확인**
14. 커밋

### Phase 4: 공통 헬퍼 정리

15. `advancedValueBlock`, `advancedDetailPane`, `advancedMessageBlock` → `Components/` 이동 (여러 시트에서 공유)
16. `binding` 헬퍼 → `SettingsViewHelpers.swift`
17. `rowNote`, `displayConnectorText` → 해당 탭 파일로 이동
18. **빌드 + 테스트 확인**
19. 커밋

---

## 추출 패턴

`private extension`으로 추출하면 `@State`/`@ObservedObject` 접근이 유지됨:

```swift
// ConnectorSettingsTab.swift
extension PromptCueSettingsView {
    var connectorsPage: some View {
        settingsScrollPage {
            connectorsContent
        }
    }

    // ... 커넥터 관련 모든 뷰 + 헬퍼
}
```

별도 struct로 빼면 프로퍼티를 바인딩으로 넘겨야 해서 리팩터링 범위가 커짐.
**Phase 2~3은 extension 추출로 안전하게, Phase 5 이후 필요 시 struct 분리.**

---

## 전제 조건

- [ ] main의 Settings 디자인 시스템 uncommitted 작업 커밋 완료
- [ ] `xcodegen generate` + `xcodebuild build` + 테스트 통과
- [ ] 분리 브랜치 생성 후 작업 (main에서 분기, 또는 별도 워크트리)

## 분리 후 기대 효과

| Before | After |
|--------|-------|
| Settings 관련 모든 작업이 1개 파일에서 충돌 | 탭별 독립 작업 가능 |
| 사이드바 애니메이션 수정 → 커넥터 코드와 diff 충돌 | `ConnectorSettingsTab.swift`만 건드리면 됨 |
| 폰트 weight 조정 → 1699줄 파일 전체 diff | `SettingsTokens.swift`만 수정 |
| PR 리뷰 시 변경 범위 파악 어려움 | 파일명만으로 영향 범위 파악 |

## project.yml 변경

신규 파일 추가 시 `xcodegen generate` 자동 반영 (sources glob 패턴).
`Package.swift` 변경 불필요 (앱 타겟 파일).
