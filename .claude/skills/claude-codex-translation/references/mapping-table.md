# Mapping Table — Claude Code → Codex

마스터 매핑 표. `_workspace/03_translation_table.md`의 시작점.

| Claude Code primitive | Codex 등가/에뮬레이션 | 구현 메커니즘 | 손실 |
|---|---|---|---|
| `.claude/skills/X/SKILL.md` | `prompts/X.md` | Codex 슬래시 트리거 또는 `codex exec --prompt-file` | 거의 없음 |
| `.claude/skills/X/references/` | 같은 위치 (상대경로 유지) | prompt가 본문에서 상대경로 참조 | 없음 |
| `.claude/agents/X.md` | `agents/X.md` + AGENTS.md 등록 | `codex exec --prompt-file agents/X.md` | model/tools frontmatter 일부 무시 |
| `Agent` 도구 (subagent 호출) | `codex exec` 서브프로세스 | working-dir 격리 + 결과 파일 회수 | 동기적 stream output 형식 차이 |
| `TeamCreate` | MCP 팀 서버 `team_create` 도구 | 자체 MCP 서버 | Codex prompt가 도구 호출 명시 필요 |
| `SendMessage` | MCP 팀 서버 `send_message` 도구 | 자체 MCP 서버 | 동기 응답 모델 차이(폴링 필요할 수 있음) |
| `TaskCreate` / `TaskUpdate` / `TaskList` | MCP 팀 서버 task 도구 | 자체 MCP 서버 + SQLite/JSON 저장소 | 영속화 위치 사용자에게 노출 필요 |
| `TaskOutput` | MCP 팀 서버 `task_get_output` | 자체 도구 | 새 도구이므로 prompt에 호출 지시 필요 |
| `WebFetch` | MCP web-fetch 서버 (별도) | 외부 서버 등록 | 사용자가 별도 설치 |
| `WebSearch` | MCP web-search 서버 (별도) | 외부 서버 등록 | 사용자가 별도 설치 |
| `Read` / `Write` / `Edit` / `Bash` / `Glob` / `Grep` | Codex 빌트인 등가 | Codex의 파일 조작 도구 | 도구명/인자 차이 |
| `subagent_type=Explore` (읽기 전용) | "읽기 전용 에이전트" 지시문 | prompt에 명시 | 도구 차단은 Codex sandbox로 강제 가능 |
| `subagent_type=Plan` | "계획 수립 prompt" 별도 파일 | prompt 패턴 | 1차 primitive 아님 |
| `subagent_type=general-purpose` | 기본 `codex exec` | — | 없음 |
| Hooks (settings.json) | Codex hooks (있으면) 또는 shell wrapper | 분석 결과에 따라 | 미지원 시 wrapper 우회 |
| CLAUDE.md | AGENTS.md | 파일명 변경 + 트리거 표현 치환 | 거의 없음 |
| `.claude-plugin/plugin.json` | Codex 플러그인 매니페스트 | 형식 변환 | schema 차이 |
| `.claude-plugin/marketplace.json` | Codex marketplace 매니페스트 | 형식 변환 | schema 차이 |
| Slash command `/foo` | Codex slash trigger 또는 `codex exec --prompt-file` | prompt 파일 배치 | trigger 형식 차이 |
| `ScheduleWakeup` / cron / 스케줄링 | `codex exec` + OS cron | 외부 cron | 1:1 대응 없음 |
