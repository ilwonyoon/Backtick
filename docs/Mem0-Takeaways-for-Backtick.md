# Mem0 Takeaways for Backtick — Execution Plan

> **Date**: 2026-03-18
> **Sources**: Agentic-Memory-Memo.md, Competitive-Landscape-and-Future-Backlogs.md, MCP-Platform-Expansion-Research.md
> **Purpose**: Mem0/OpenMemory 리서치에서 Backtick에 현실적으로 반영할 항목만 추려 실행 가능한 형태로 정리

---

## 1. 핵심 전제: Backtick ≠ Mem0

두 제품은 근본적으로 다른 시장을 대상으로 한다. 이 차이를 유지하는 것이 전략의 핵심이다.

| 축 | Mem0 | Backtick |
|---|---|---|
| 대상 | AI 앱을 만드는 개발자 | AI 도구를 쓰는 사람 |
| 입력 | `memory.add(messages)` 코드 호출 | 인간이 캡처 or AI가 MCP로 저장 |
| 지능 | 자체 LLM 운영 (비용 발생) | 사용자가 이미 구독한 AI를 활용 |
| 저장 | atomic facts (벡터 DB) | 읽을 수 있는 project × topic 문서 |
| 비용 | 사용량 기반 $19–249/mo | 일회성 또는 정액 |

**아키텍처 원칙**: Backtick은 persistence layer다. intelligence는 사용자의 Claude/ChatGPT 구독이 담당한다. Mem0처럼 자체 LLM을 돌리지 않는다.

---

## 2. 가져올 것 (ADOPT)

### 2.1 Two-Tier Retrieval — MCP 응답 경량화

**Mem0에서 배울 점**: Mem0의 hybrid retrieval은 과하지만, "요약 먼저 → 상세 on demand" 패턴은 Felix/OpenClaw에서도 검증됨.

**Backtick 적용**:
- `list_notes` MCP 응답은 제목 + 1줄 요약만 반환
- `get_note`로 전체 내용 조회하는 2단계 구조
- AI의 context window를 아끼면서 필요한 정보만 전달

**현재 상태**: BacktickMCP에 `list_notes` / `get_note` 분리는 이미 존재. 요약 필드가 없으면 추가 필요.

**우선순위**: P1 — Stack 카드 수가 늘어나면 즉시 필요

---

### 2.2 Immutable History with Supersession — Warm Memory 데이터 모델

**Mem0에서 배울 점**: Mem0는 fact를 업데이트할 때 이전 버전을 덮어쓴다. 이게 [memory corruption 버그](https://github.com/mem0ai/mem0/issues/3322)의 원인. Felix는 이를 `supersededBy` 포인터로 해결 — 절대 삭제하지 않고 이전 버전을 가리킨다.

**Backtick 적용**:
- Warm Memory 설계 시 `supersededBy` 필드를 데이터 모델에 포함
- 기존 fact를 업데이트하면 새 레코드 생성 + 이전 레코드에 포인터
- "지난달 이 프로젝트에 대해 내가 알고 있던 것" 시간여행 가능

**반면교사**: Mem0의 이름이 fact에서 빠지는 corruption 버그는 덮어쓰기 방식의 실패. Backtick은 이를 피한다.

**우선순위**: P1 — Warm Memory 아키텍처 설계 시 Day 1에 반영

---

### 2.3 자동 Hot → Warm 프로모션 — TTL 만료 시 구조화

**Mem0에서 배울 점**: Mem0는 AI가 자동으로 fact를 추출해서 저장한다. 이 "자동 추출" 아이디어 자체는 좋지만, 블랙박스 방식은 문제 (사용자가 뭐가 저장됐는지 모른다).

**Backtick 적용**:
- Stack 카드가 TTL(8h) 내에 실행되지 않으면, 자동 삭제 대신 Warm Memory 프로모션 제안
- AI가 카드 내용을 project × topic 구조로 압축하여 Warm Memory 초안 생성
- **사용자 리뷰 단계 필수** — Mem0의 블랙박스와 차별화. "AI saves + human reviews"

**반면교사**: Mem0는 사용자가 뭐가 저장됐는지 볼 수 없다. Backtick은 리뷰 루프를 보장한다.

**우선순위**: P1 — Warm Memory 이후

---

### 2.4 One-Click 설치 경험 — Mem0의 반면교사

**Mem0의 문제**: Docker + Postgres + Qdrant + OpenAI API key 필요. "Normal people can't install this."

**Backtick이 이미 하고 있는 것**:
- `.app` 하나로 설치
- Claude Desktop은 이번 커밋에서 Connect 버튼 한 번으로 config 자동 작성
- Claude Code / Codex는 터미널 명령어 복사-붙여넣기

**추가 강화 방안**:
- Cursor / Windsurf용 one-click config write도 Claude Desktop 패턴 적용
- 첫 실행 시 "어떤 AI 도구를 쓰시나요?" → 자동 커넥터 설정 온보딩

**우선순위**: P0 — 이미 진행 중, 플랫폼 확장 시 반복 적용

---

### 2.5 Proactive Memory Loop — 저장과 조회 양방향 자동화

**문제의 본질**: 메모리 시스템의 가치는 *저장*과 *조회* 양쪽이 자연스럽게 일어날 때만 성립한다. 한쪽이 끊기면 전체가 무용지물이 된다.

- Mem0: 개발자가 코드로 `memory.add()` → `memory.search()` 양방향을 직접 제어
- Muninn (실사용 경험): AI가 "이거 Muninn에 저장할까요?" 주기적으로 물어보는 패턴이 매우 효과적 → 하지만 MCP 연결이 끊어지면 저장이 멈추고, 사용자가 인지 못한 채 메모리가 쌓이지 않는 문제 발생

**Backtick이 풀어야 하는 두 방향**:

#### A. 저장 방향 — "이거 저장할까요?" 루프

**현재 상태**: `create_note` tool이 있지만, AI가 자발적으로 "이 대화 내용을 Backtick에 저장하겠습니다"라고 하지 않음. 사용자가 명시적으로 요청해야 저장.

**목표**: Muninn처럼 AI가 대화 흐름에서 저장할 만한 내용을 감지하고 제안.

**구현 방안**:

1. **`create_note` tool description 강화** (P0, 비용 제로)
   - 현재: `"Create a Stack note directly in Backtick storage."`
   - 개선: `"Save important context, decisions, or action items to Backtick for use in future AI sessions. Call this proactively when the conversation produces reusable knowledge — project decisions, architecture choices, task outcomes, or anything the user might need in a different tool or session. Ask the user before saving."`
   - AI가 "이건 저장할 만하다"고 판단할 기준을 description에 녹이는 것

2. **연결 상태 모니터링** (P1)
   - Muninn의 핵심 교훈: 연결이 끊어져도 사용자가 모름 → 메모리 공백 발생
   - BacktickMCP 프로세스 health check + 메뉴바 상태 표시 (연결됨/끊어짐)
   - 끊어졌을 때 알림 → 재연결 유도

3. **세션 종료 시 자동 요약 제안** (P2)
   - 긴 대화 끝에 "이 세션의 주요 결정사항을 Backtick에 저장할까요?" 자동 제안
   - CLAUDE.md / .cursorrules에 "Before ending a session, offer to save key decisions to Backtick" 규칙 추가

#### B. 조회 방향 — 키워드 트리거 자동 조회

**현재 상태**: `list_notes`가 있지만 description이 `"List Stack notes directly from Backtick storage."` — AI가 언제 이걸 써야 하는지 유도가 전혀 없음.

**목표**: 사용자가 프로젝트명, 기술 스택, 이전에 저장한 주제 등을 언급하면 AI가 자발적으로 "관련 메모리를 확인해볼게요"라고 Backtick을 조회.

**구현 방안**:

1. **`list_notes` tool description 강화** (P0, 비용 제로)
   - 현재: `"List Stack notes directly from Backtick storage."`
   - 개선: `"List the user's Stack notes from Backtick. Call this at the start of a new task, when the user mentions a project name, technology, or topic that might have prior context, or when you need background before making a recommendation. Notes contain decisions, context, and action items the user saved from previous AI sessions across tools."`
   - 핵심: "프로젝트명이 언급되면 조회하라"를 description에 명시

2. **MCP resources로 활성 Stack 요약 상시 노출** (P1)
   - tool 호출 없이 AI가 볼 수 있는 MCP resource로 "활성 노트 목록 (제목만)" 노출
   - Claude Desktop, Cursor 등 resource 지원 클라이언트에서 세션 시작 시 자동으로 context에 포함
   - AI가 "아, 이 사용자는 ProjectX 관련 노트가 3개 있구나" 인지 → 관련 대화 시 자동 조회

3. **CLAUDE.md / .cursorrules 가이드 자동 생성** (P1)
   - 커넥터 설정 시 프로젝트 규칙 파일에 자동 추가:
     ```
     When the user mentions a project, feature, or topic, check Backtick
     (list_notes) for related context before responding.
     At session start, list active Backtick notes to load prior context.
     When producing important decisions or action items, offer to save
     them to Backtick (create_note) for cross-session persistence.
     ```
   - 사용자가 코드 없이 AI의 행동을 제어하는 유일한 방법

#### 왜 양방향 모두 필요한가

```
저장만 되고 조회 안 됨 → 쓰레기통 (넣기만 하고 안 꺼냄)
조회만 되고 저장 안 됨 → 빈 창고 (꺼낼 게 없음)
양쪽 다 자동   → Muninn이 잘 작동할 때의 경험
양쪽 다 끊어짐  → Muninn 연결 끊어졌을 때의 경험
```

Mem0는 개발자가 코드로 양방향을 제어한다. Backtick 사용자는 코드를 안 쓰므로, **MCP tool description + resource + 규칙 파일** 3개 레이어가 같은 역할을 해야 한다.

**현재 tool description 진단** (즉시 개선 가능):

| Tool | 현재 description | 문제 |
|---|---|---|
| `list_notes` | "List Stack notes directly from Backtick storage." | 언제 쓸지 유도 없음 |
| `get_note` | "Fetch one Stack note and its copy-event history." | OK (list 후 호출이 자연스러움) |
| `create_note` | "Create a Stack note directly in Backtick storage." | 자발적 저장 유도 없음 |
| `update_note` | "Update Stack note text or metadata without copying it." | OK |
| `delete_note` | "Delete a Stack note directly from Backtick storage." | OK |
| `mark_notes_executed` | "Mark Stack notes executed by recording copied state..." | OK |

→ `list_notes`와 `create_note` description 개선이 Phase 1의 최우선 실행 항목.

---

### 2.6 Proactive Memory Loop — 크로스 프로덕트 리서치 근거

> 이 섹션은 2.5의 방향성을 뒷받침하는 외부 리서치 결과를 정리한다.

#### A. Tool Description은 사실상 System Prompt이다

**근거 1 — Tenable "Tool Insertion" 연구**: MCP tool의 `description` 필드에 "Call this before any other tool"을 넣으면 LLM이 실제로 매번 해당 tool을 먼저 호출한다. Description은 문서가 아니라 **행동 지시**다. 같은 메커니즘으로 firewall tool, logging tool 등을 구현한 사례 존재.

**근거 2 — "Smelly Descriptions" 논문** (Hasan et al., arXiv:2602.14878): 103개 MCP 서버의 856개 tool 분석. 97.1%가 description에 최소 1개 결함 보유. 가장 중요한 누락 요소는 **Guidelines** (언제, 왜 쓰는지). Guidelines 추가 시 task success rate +5.85pp, partial goal completion +15.12%. 단, 모든 요소를 다 넣으면 토큰 비용 67% 증가 → **Guidelines + Purpose 2개만 compact하게** 넣는 것이 최적.

**근거 3 — MCP Memory Server 공식 패턴**: Anthropic의 공식 MCP Memory Server는 tool description을 최소화하되, companion system prompt로 행동을 제어:
> "Always begin your chat by saying only 'Remembering...' and retrieve all relevant information."
> "At the end of each response, update your memory with any new information."

이것이 **description은 compact + 규칙 파일로 행동 강제** 패턴의 원형.

**Backtick 시사점**: 2.5에서 제안한 description 개선은 단순 문구 변경이 아니라, LLM 행동을 직접 조종하는 가장 비용 효율적인 수단. 다만 Anthropic 경고: Opus 4.6은 이전 모델보다 훨씬 proactive하므로, 지나치게 공격적인 지시는 과잉 호출을 유발할 수 있다 → **"Ask the user before saving"** 같은 확인 단계가 필수.

#### B. 조회 패턴: 매 호출 injection vs. 키워드 트리거

| 제품 | 조회 방식 | 장점 | 단점 |
|---|---|---|---|
| **Mem0** | 개발자가 `search()` 호출 → 결과를 system prompt에 삽입 | 완전 제어 | Backtick 사용자는 코드를 안 씀 |
| **Zep** | `get_user_context()` → "Context Block" 한 문자열 조립 (summary/basic 모드) | 개발자 친화적, 템플릿 지원 | 역시 코드 필요 |
| **Khoj** | 매 쿼리마다 자동 semantic search | 사용자 개입 없음 | 매번 검색 비용 발생, 불필요한 context 주입 |
| **CLAUDE.md** | 세션 시작 시 자동 로드 | 확실, 예측 가능 | 정적 (대화 중 변화 반영 안 됨) |
| **MCP Resource** | 클라이언트가 세션 시작 시 resource 자동 주입 | tool 호출 불필요 | 대부분 클라이언트가 아직 미지원 |

**Backtick 최적 조합**:
1. MCP resource로 "활성 노트 제목 목록"을 세션 시작 시 passive 주입 (Zep의 Context Block 모델)
2. `list_notes` description에 "프로젝트/기술명 언급 시 조회" 유도 (키워드 트리거)
3. CLAUDE.md/.cursorrules에 "세션 시작 시 Backtick 확인" 규칙 (확정적 행동 강제)

→ 3개 레이어 중 1개만 작동해도 조회가 일어나는 redundant 설계.

#### C. 저장 패턴: 자동 추출 vs. AI 제안 vs. 사용자 명시

| 제품 | 저장 방식 | 확인 절차 | 실패 모드 |
|---|---|---|---|
| **Mem0** | `add()` 시 LLM이 atomic fact 자동 추출 (AUDN: Add/Update/Delete/Noop) | 없음 (블랙박스) | 추출 LLM 실패 시 저장 안 됨, 기존 데이터 무손상 |
| **Zep** | 메시지 추가 시 비동기 자동 추출 → temporal knowledge graph | 없음 | 3-tier 중복 (episode/entity/community)으로 부분 실패 허용 |
| **Screenpipe** | 완전 자동 (스크린 캡처 + OCR) | 없음 (opt-out) | 로컬 전용이라 네트워크 무관 |
| **Obsidian MCP** | AI가 `create_entities` tool 호출로 결정 | AI 판단에 의존 | tool description이 약하면 저장 안 함 |
| **Muninn** | AI가 "저장할까요?" 제안 → 사용자 승인 | 있음 (대화형) | MCP 연결 끊기면 제안 자체가 안 됨 |

**Backtick 최적 선택: Muninn 모델 + 연결 안정성 강화**
- AI가 제안 → 사용자 승인 (Mem0의 블랙박스 거부)
- 연결 끊김 감지 + 알림 (Muninn의 실패 모드 보완)
- `create_note` description에 "중요한 결정/컨텍스트 발생 시 저장 제안" 유도

#### D. Cursor Memories 실패 사례 — 경고

Cursor는 2025년 중반 대화에서 자동으로 fact를 누적하는 "Memories" 기능을 출시했다가 v2.1.x에서 제거. 이유: **행동이 예측 불가능**해짐. 사용자에게 Memories를 export해서 Rules 파일로 변환하라고 안내.

**교훈**: 자동 누적 메모리 < 정적 규칙 파일 (AI 행동 제어 측면에서). Backtick의 Warm Memory가 자동 프로모션을 할 때, **반드시 사용자 리뷰 단계**를 거쳐야 한다. 2.3의 "AI saves + human reviews" 원칙이 더욱 강화됨.

#### E. "Capture Everything, Filter at Retrieval" 원칙 (Screenpipe 모델)

Screenpipe의 아키텍처: Capture → Processing → Storage → Retrieval. 캡처 시점에 중요도를 판단하지 않고, 조회 시점에 relevance를 결정.

**Backtick과의 정렬**: Backtick의 Capture 패널이 정확히 이 모델. "UI subtraction test: if a capture UI element can be removed and capture still works, remove it." 캡처는 frictionless dump, 지능은 Stack에서 발휘.

---

## 3. 참고만 할 것 (WATCH)

### 3.1 Graph Memory — 복잡한 관계 추론

**Mem0의 강점**: Mem0-g는 entity 간 관계를 그래프로 저장해서 "A 프로젝트의 B 컴포넌트가 C 라이브러리에 의존" 같은 복잡한 추론 가능. $249/mo 티어.

**Backtick에의 시사점**: 지금은 과하다. 하지만 Warm Memory에 project × topic 이 축적되면 자연스럽게 관계 그래프가 필요해질 수 있다.

**판단 기준**: Warm Memory 문서가 100개를 넘고, 사용자가 "이 프로젝트와 관련된 모든 것" 같은 쿼리를 하기 시작하면 검토.

**옵션**: 직접 구현 대신 Mem0 또는 Zep을 백엔드 인프라로 활용 가능 (Competitive-Landscape 문서의 "potential partner" 평가).

---

### 3.2 Hybrid Search (BM25 + Vector + LLM Re-ranking)

**Mem0의 강점**: 22+ 벡터 백엔드, hybrid retrieval pipeline.

**Backtick에의 시사점**: SQLite FTS로 시작하되, Warm Memory 규모가 커지면 semantic search 필요. Felix의 QMD (BM25 + vector + LLM re-ranking over SQLite)가 참고 모델.

**판단 기준**: Warm Memory 수백 개 문서 이상일 때. 현재는 SQLite FTS 충분.

---

### 3.3 Cross-Platform Memory Sync

**Mem0의 접근**: API 기반 중앙 저장소로 어디서든 접근.

**Backtick의 접근**: MCP 프로토콜로 각 AI 도구에 컨텍스트를 push. 중앙 저장소(SQLite)는 로컬에 유지.

**시사점**: iCloud 동기화가 우선. Mem0식 API 서버는 팀 기능이 필요해질 때 검토.

---

## 4. 안 할 것 (REJECT)

| Mem0 패턴 | 왜 안 하는가 |
|---|---|
| 자체 LLM 운영 | 사용자가 이미 AI를 구독하고 있다. 별도 inference 비용은 Backtick의 가격 이점을 파괴한다 |
| Docker / DB 인프라 | ".app 하나"가 Backtick의 핵심 UX. 인프라 의존성 추가는 설치 마찰을 만든다 |
| SDK / API 제공 | Backtick은 개발자 인프라가 아니라 사용자 도구다. `pip install` 경로는 없다 |
| Atomic fact 저장 | "user prefers dark mode" 같은 원자적 사실은 Backtick의 단위가 아니다. Backtick은 읽을 수 있는 project × topic 문서를 저장한다 |
| 사용량 기반 과금 | Backtick은 일회성/정액. $249/mo graph memory 티어 같은 구조는 타겟 사용자에게 맞지 않다 |
| 블랙박스 메모리 | Mem0는 뭐가 저장됐는지 사용자가 볼 수 없다. Backtick은 항상 리뷰 가능해야 한다 |

---

## 5. 실행 로드맵 요약

```
Phase 1 (현재 — 비용 제로, 즉시 실행)
├── ✅ Claude Desktop one-click config write
├── 🔲 list_notes description 강화 (Guidelines + Purpose, compact)
│   → "Call at task start, when project/tech mentioned, or before recommendations"
├── 🔲 create_note description 강화
│   → "Save decisions/context proactively. Ask user before saving."
│   ⚠️ Opus 4.6 과잉 호출 주의 — 확인 단계 필수
├── 🔲 list_notes 요약 필드 추가 (Two-Tier Retrieval)
└── 🔲 Cursor / Windsurf one-click 패턴 확장

Phase 2 (Proactive Loop 인프라)
├── 🔲 MCP resource: "활성 노트 제목 목록" 상시 노출
│   → Zep Context Block 모델 참고, resource 미지원 클라이언트 fallback 필요
├── 🔲 CLAUDE.md / .cursorrules 자동 가이드 생성 옵션
│   → MCP Memory Server의 companion prompt 패턴 적용
├── 🔲 MCP 연결 상태 모니터링 + 메뉴바 표시
│   → Muninn 연결 끊김 문제의 직접적 해결
├── 🔲 supersededBy 포인터 데이터 모델 설계
├── 🔲 Hot → Warm 자동 프로모션 + 사용자 리뷰 루프
│   ⚠️ Cursor Memories 실패 사례: 리뷰 없는 자동 누적은 위험
└── 🔲 project × topic 구조 정의

Phase 3 (스케일)
├── 🔲 SQLite FTS → hybrid search 검토 (Warm Memory 수백 개 시점)
├── 🔲 Graph memory 필요성 평가 (Warm Memory 100개+ 시점)
├── 🔲 Mem0 AUDN 패턴 검토 (Stack → Warm 중복 제거용)
│   → LLM이 기존 fact 대비 Add/Update/Delete/Noop 결정
└── 🔲 Zep temporal KG 또는 Mem0를 백엔드 파트너로 활용 검토
```

---

## 6. 한 줄 요약

> Mem0의 **검증된 패턴**(two-tier retrieval, immutable history, 자동 프로모션, proactive injection)은 가져오되, **아키텍처**(자체 LLM, Docker 인프라, SDK 모델)는 가져오지 않는다. Backtick은 persistence layer이지 intelligence layer가 아니다. Tool description은 사실상 system prompt — 여기가 Phase 1의 최고 레버리지 포인트다.

---

## 7. 리서치 출처

- [Anthropic: Writing effective tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Tenable: MCP Prompt Injection — Not Just For Evil](https://www.tenable.com/blog/mcp-prompt-injection-not-just-for-evil)
- [arXiv: MCP Tool Descriptions Are Smelly (2602.14878)](https://arxiv.org/abs/2602.14878)
- [MCP Memory Server](https://github.com/modelcontextprotocol/servers/tree/main/src/memory)
- [Basic Memory Skills](https://github.com/basicmachines-co/basic-memory-skills)
- [Mem0 Docs](https://docs.mem0.ai/platform/quickstart)
- [Zep: Temporal Knowledge Graph Architecture (arXiv)](https://arxiv.org/abs/2501.13956)
- [Screenpipe Architecture](https://docs.screenpi.pe/architecture)
- [Cursor Rules for AI](https://docs.cursor.com/context/rules-for-ai)
- [Claude Code Memory System](https://code.claude.com/docs/en/memory)
