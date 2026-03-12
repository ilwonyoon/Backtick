# Settings View Decomposition Plan

## 상태

- 2026-03-12 기준 Phase 1~4 완료
- `PromptCueSettingsView` live 경로에는 `.sheet(...)` modifier가 없었고, connector guided sheet state/view는 모두 미연결 dead code로 판정되어 삭제함
- 현재 남은 작업은 이 문서 기준으로 없음. Architecture Cleanup 관점의 남은 범위는 optional Phase 4뿐임

## 분해 전 기준선

```
PromptCueSettingsView.swift (1699줄)
├── 메인 컨테이너 + 사이드바 + 라우터
├── general / capture / stack / connectors 탭 본문
├── guided connector sheet 3종
├── 미사용 connectorSection / missingCLIConnectorSection
├── connector 헬퍼
└── 공통 헬퍼
```

## 실제 결과 구조

```
PromptCueSettingsView.swift (207줄)
├── 프로퍼티, init
├── body
├── sidebar / router
└── settingsScrollPage

GeneralSettingsTab.swift (100줄)
├── generalPage
├── appearance / shortcuts / iCloud
└── cloudSyncStatusBadgeTone

CaptureSettingsTab.swift (110줄)
├── capturePage
├── screenshot section
└── screenshot 상태 헬퍼

StackSettingsTab.swift (91줄)
├── stackPage
└── retention / export tail

ConnectorSettingsTab.swift (611줄)
├── connectorsPage
├── focusedConnectorRow
├── connector badge / inline setup / repair / tools
├── connector text formatting helpers
└── ConnectorChipTone

SettingsViewHelpers.swift (17줄)
├── binding helper
└── rowNote
```

## 실행 기록

### Phase 1: 정리

- [x] `connectorSection`, `missingCLIConnectorSection` 삭제
- [x] 미연결 connector guided sheet state/view 삭제
- [x] dead token 정리

### Phase 2: 탭 분리

- [x] `GeneralSettingsTab.swift`
- [x] `CaptureSettingsTab.swift`
- [x] `StackSettingsTab.swift`

### Phase 3: 커넥터 분리

- [x] `ConnectorSettingsTab.swift`
- [x] live connector inline setup / repair / tools helper 이동
- [x] 시트 파일 분리 계획은 폐기
  이유: live 경로에 `.sheet(...)` attachment가 없어 분리 대상이 아니라 제거 대상이었음

### Phase 4: 공통 헬퍼 정리

- [x] `binding` → `SettingsViewHelpers.swift`
- [x] `rowNote` → `SettingsViewHelpers.swift`
- [x] connector-specific code block / message helper는 `ConnectorSettingsTab.swift` 내부에 유지
  이유: 더 이상 cross-file shared helper가 아니고 connector 탭에서만 사용됨

## 구현 메모

- 별도 파일 extension 추출을 위해 `@ObservedObject` / `@State` 저장 프로퍼티 접근 수준을 `private`에서 타입 내부 공유 가능 수준으로 넓힘
- `settingsScrollPage`도 cross-file extension에서 호출할 수 있도록 타입 내부 공유 수준으로 조정함
- `SettingsTokens`에서 dead helper 전용 token만 제거함:
  - `advancedLabelColumnWidth`
  - `connectorCardPadding`

## 검증

- [x] `xcodegen generate`
- [x] `swift test`
- [x] `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- [x] `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test`

## 후속 메모

- Settings 분해는 종료 상태다
- 이후 Settings 작업은 해당 탭 파일만 열어서 진행하면 된다
- connector guided sheet UX를 다시 도입하려면, 새 flow를 live attachment와 함께 새 계약으로 설계해야 한다
