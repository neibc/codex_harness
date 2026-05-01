# Team Server Storage Schema

## SQLite (권장)

`~/.codex/teams.sqlite` (단일 파일, 모든 팀 공유)

### 테이블 — `mcp-server-skeleton.md`의 DDL 그대로 사용

### 인덱스

```sql
CREATE INDEX idx_messages_team_to_id ON messages(team_id, to_member, id);
CREATE INDEX idx_tasks_team_status   ON tasks(team_id, status);
```

### Append-only 정책

- `messages`는 절대 UPDATE/DELETE 하지 않는다 (감사 추적용).
- `tasks`는 status 변경 시 UPDATE — 단 변경 이력은 별도 `task_history` 테이블에 INSERT.

## JSONL 대안 (영속화 라이브러리 의존이 부담될 때)

```
~/.codex/teams/
└── <team_id>/
    ├── team.json          # 한 번 작성, 수정 시 덮어쓰기
    ├── messages.jsonl     # 한 줄 = 한 메시지
    └── tasks.jsonl        # 한 줄 = 한 태스크 상태 스냅샷 (마지막이 최신)
```

각 줄 schema:

```jsonc
// messages.jsonl
{"id": 17, "from": "translator", "to": "builder", "content": "...", "tags": [], "ts": "2026-05-02T12:34:56Z"}

// tasks.jsonl (각 줄이 스냅샷)
{"task_id": "t1", "subject": "...", "status": "in_progress", "owner": "builder", "ts": "..."}
{"task_id": "t1", "subject": "...", "status": "completed", "owner": "builder", "ts": "..."}
```

## 동시성

- SQLite: WAL 모드 활성화 (`PRAGMA journal_mode=WAL`)
- JSONL: 파일 단위 advisory lock (`fcntl.flock` 또는 npm `proper-lockfile`)

## 백업/이관

- SQLite 단일 파일 → 그대로 복사
- JSONL 디렉토리 → 트리 통째로 복사

## TTL / GC

- 종료된 팀(`team_destroy` 호출 후)은 7일 보존 후 자동 삭제 옵션 (config로 제어)
- 아카이브 모드: 삭제 대신 `~/.codex/teams/_archive/`로 이동
