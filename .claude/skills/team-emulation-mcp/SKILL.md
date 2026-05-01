---
name: team-emulation-mcp
description: Codex CLI에서 Claude Code의 Agent Team primitive(TeamCreate/SendMessage/TaskCreate)를 MCP 서버로 에뮬레이션하는 설계와 구현 가이드. MCP 도구 시그니처, 메시지 저장 schema, 동기화 모델, 다중 Codex 세션 협업 방법을 다룬다. "Codex에서 에이전트 팀을 어떻게 만들지", "TeamCreate/SendMessage 대체", "다중 codex exec 세션 협업" 같은 질문에 반드시 사용.
---

# Team Emulation via MCP

Codex CLI에 **Agent Team 1차 primitive가 없으므로**, MCP 서버로 팀 기능을 에뮬레이션하는 설계 패턴.

## 1. 핵심 아이디어

```
[Codex 세션 A: orchestrator]      [Codex 세션 B: agent-1]      [Codex 세션 C: agent-2]
            ↕ (MCP)                          ↕                            ↕
                            ┌───────────────────────────────┐
                            │     Team MCP Server (stdio)   │
                            │  - team_create               │
                            │  - send_message              │
                            │  - recv_messages             │
                            │  - task_create / update / list│
                            │  - team_destroy              │
                            └───────────────────────────────┘
                                          ↓
                            [영속 저장소: SQLite or JSON files]
```

- Codex 세션은 모두 같은 MCP 팀 서버에 연결.
- 메시지/작업 상태는 MCP 서버 프로세스 또는 그 뒤의 영속 저장소에 보관.
- Codex prompt가 **명시적으로** 도구를 호출(자동 호출이 약함을 가정).

## 2. MCP 도구 시그니처 (초안)

```jsonc
// team_create
{
  "name": "team_create",
  "input": {
    "team_name": "string",
    "members": ["string"],   // 에이전트 이름 목록
    "leader": "string"       // 보통 호출자 자신
  },
  "output": { "team_id": "string" }
}

// send_message
{
  "name": "send_message",
  "input": {
    "team_id": "string",
    "from": "string",
    "to": "string",        // 또는 "*" 브로드캐스트
    "content": "string",
    "tags": ["string"]?    // 선택
  },
  "output": { "message_id": "string", "ts": "ISO8601" }
}

// recv_messages
{
  "name": "recv_messages",
  "input": {
    "team_id": "string",
    "as": "string",         // 수신자 이름
    "since": "ISO8601 | message_id"?,
    "limit": "int?"
  },
  "output": { "messages": [/* {id, from, to, content, tags, ts} */] }
}

// task_create
{
  "name": "task_create",
  "input": {
    "team_id": "string",
    "subject": "string",
    "description": "string",
    "owner": "string?",
    "blocked_by": ["string"]?
  },
  "output": { "task_id": "string" }
}

// task_update
{
  "name": "task_update",
  "input": {
    "team_id": "string",
    "task_id": "string",
    "status": "pending|in_progress|completed|deleted?",
    "owner": "string?",
    "metadata": "object?"
  }
}

// task_list / task_get_output 등 보조 도구
```

## 3. 저장소 schema

기본은 SQLite 1개 파일(`~/.codex/teams/<team_id>.sqlite`). 또는 JSON 디렉토리 구조:

```
~/.codex/teams/<team_id>/
├── team.json           # name, members, leader, created_at
├── messages.jsonl      # append-only
└── tasks.jsonl         # append-only (마지막 entry가 최신)
```

- append-only를 추천 — 디버깅/감사 용이.
- 동시성 — 파일 락(`fcntl`) 또는 SQLite WAL.

## 4. 동기화 모델

### 4-1. 송신은 push, 수신은 polling

- 송신: `send_message` 즉시 디스크 flush
- 수신: 수신자가 주기적으로 `recv_messages(since=last_seen)` 호출
- **Codex prompt는 폴링 루프를 명시해야 함** — Claude처럼 "메시지 도착 시 자동 깨움"이 없음

### 4-2. 종료 조건

팀 작업이 끝났는지 어떻게 아는가?
- **단순 모드:** 오케스트레이터가 "모든 task_id가 completed일 때까지 폴링" → `task_list`
- **신호 모드:** 종료 시 `send_message(to="*", content="<DONE>")`로 브로드캐스트

### 4-3. 데드락 방지

- 모든 task에 `timeout_at` 설정 권장 (서버가 만료 task에 status=`timed_out` 표시)
- 오케스트레이터는 `team_destroy(team_id)`를 finally 블록에서 호출하여 GC 보장

## 5. 구현 스택 선택

| 후보 | 장점 | 단점 |
|------|------|------|
| **Node.js + @modelcontextprotocol/sdk** | npm 생태계, Codex와 같은 패키징 | 의존성 큼 |
| **Python + mcp 라이브러리** | SQLite 표준 라이브러리, 간결 | Python 런타임 별도 설치 |
| **Rust** | 단일 바이너리, Codex와 같은 언어 | 개발/이터레이션 느림 |

**1차 권장: Node.js (TypeScript)** — 사용자가 이미 npm으로 codex를 깔았으므로 추가 의존이 적음. 후속에 Rust 단일 바이너리로 컴파일 가능.

## 6. 등록 절차 (사용자 측)

```bash
# 1. 팀 서버 빌드
cd mcp-team-server
npm install && npm run build

# 2. Codex에 등록 (정확한 인자는 codex-internals-analyst 보고서 참조)
codex mcp add team \
  --command "node" \
  --args "$(pwd)/dist/index.js"

# 3. 확인
codex mcp list   # team이 보여야 함
```

> 정확한 명령 형식은 `codex mcp add --help` 실측에 따른다. 이 문서는 인터페이스 컨셉.

## 7. 한계 인정

- Claude의 `SendMessage`는 동기 응답 모델이지만 우리 팀 서버는 비동기/폴링. 응답 지연 발생.
- Codex prompt가 도구를 자발적으로 호출하지 않으면 팀 통신이 멈춤 → prompt 작성 시 명시 호출 지시 필수.
- 영속 저장소는 로컬 파일 — 다른 머신에서 같은 팀에 합류하려면 경로 공유 필요(NFS/sync 등 사용자 책임).

## 참조

- `references/mcp-server-skeleton.md` — 최소 동작 Node.js MCP 서버 코드 스케치
- `references/storage-schema.md` — SQLite/JSONL 정확한 schema
- `references/polling-patterns.md` — Codex prompt에서 폴링 루프를 안전하게 쓰는 패턴
