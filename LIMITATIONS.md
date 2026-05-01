# Known Limitations — codex-harness

revfactory/harness(Claude Code 1.2.0) → Codex CLI 0.125.0 포팅 시 발생하는 기능 손실과 그 완화 방법.

근거: `_workspace/01_codex_primitives.md` 실측, `_workspace/03_translation_table.md` §9 매핑 결정.

---

## 1. SendMessage 동기 응답 모델 손실

- **Claude:** `SendMessage`는 메시지 도착 즉시 수신자가 알 수 있다 (런타임 스케줄러).
- **Codex:** 외부 MCP team server를 통해 push 후 polling 분리 — 즉시 wake-up 없음.
- **영향:** 짧은 ping-pong 시 응답 지연 (폴링 인터벌 1~10초만큼).
- **완화:** 팀원 prompt에 "매 turn 시작 시 `recv_messages({since: <cursor>})` 호출" 명시.
  - `skills/harness/SKILL.md` 본문이 이 폴링 규칙을 강제한다.
  - 폴링 인터벌 지수 증가(1s → 2s → 4s, max 30s)로 부하 제어.

## 2. 빌트인 subagent_type 카테고리 부재

- **Claude:** `Explore`(읽기 전용), `Plan`(설계 전용), `general-purpose`가 1차 primitive로 존재.
- **Codex:** 동등 카테고리 없음. `--sandbox` 모드와 prompt 지시문으로 우회.
- **완화:**
  - `Explore` → `codex exec -s read-only` (쓰기 도구 + 네트워크 차단)
  - `Plan` → 일반 `codex exec` + prompt 본문에 "코드 수정 금지, 설계 문서만" 지시
  - `general-purpose` → 기본 `codex exec`

## 3. WebFetch / WebSearch 빌트인 부재

- **Claude:** 빌트인 도구.
- **Codex:** 별도 MCP 서버 등록 필요. `codex exec --search`(Responses web_search)는 일부 시나리오에서 사용 가능하지만 1차 도구는 다름. feature `web_search_request=deprecated`로 향후 제거 가능성.
- **완화:** README에 `codex mcp add web-fetch -- <cmd>` 또는 `codex mcp add web-search -- <cmd>` 등록 절차 안내.

## 4. PreToolUse/PostToolUse hook 이벤트 Unknown

- **Claude:** PreToolUse/PostToolUse/UserPromptSubmit/Notification/Stop 등 다양한 hook 이벤트.
- **Codex:** 실측 확인된 이벤트는 `SessionStart`(matcher: startup|resume|clear|compact)와 `SessionEnd` 두 종류만. 그 밖은 Unknown.
- **영향:** 도구 호출 직전/직후 검증 hook을 구현할 수 없다.
- **완화:** `codex exec --ask-for-approval untrusted|on-request|on-failure|never` 정책으로 도구 호출 승인 흐름을 우회.

## 5. AGENTS.md upward search 없음

- **Claude:** `CLAUDE.md`는 상위 디렉토리에서 자동 머지될 가능성이 있다.
- **Codex:** cwd의 단일 `AGENTS.md`만 자동 로드 (실측 — `01 §3.6`).
- **영향:** monorepo의 서브 패키지에서 부모 AGENTS.md를 참조 불가.
- **완화:** 루트 AGENTS.md에 모든 도메인 트리거 + 라우팅 표를 집약. `-C <dir>`로 호출 시 해당 dir의 AGENTS.md를 사용. 미래 feature `child_agents_md` (under development)가 stable되면 재포팅.

## 6. settings.json 미세 권한 정책 손실

- **Claude:** 도구별 allow/deny 룰 (settings.json `permissions`).
- **Codex:** `--sandbox` 모드(`read-only`/`workspace-write`/`danger-full-access`) + `~/.codex/rules/default.rules`(execpolicy DSL `prefix_rule(...)`)로 거칠게만 매핑. 입자도 차이 큼.
- **완화:** 정책별 별도 `--profile`을 `~/.codex/config.toml`에 정의. 사용자에게 "Claude의 fine-grained permissions은 Codex에서 sandbox 모드로 단순화된다"고 명시.

## 7. ScheduleWakeup / 셀프 페이싱 부재

- **Claude:** 셀프 페이싱 가능 (모델이 시간 기반 wake-up 도구 호출).
- **Codex:** 1차 primitive 없음.
- **완화:** OS cron + `codex exec --prompt-file <task>.md` 외부 스케줄러 사용. README에 cron 예시 안내.

## 8. 자동 컨텍스트 압축 정책 차이 Unknown

- **Claude:** 대화 길이가 한도에 다가가면 자동 요약 압축.
- **Codex:** 동등 동작 Unknown — 수동 세션 분할 또는 `codex resume`/`codex fork`로 우회 가능.
- **완화:** 오케스트레이터가 phase 사이에 산출물을 파일로 떨어뜨려 컨텍스트 의존을 최소화. `_workspace/<phase>_<artifact>.md` 컨벤션 강제.

## 9. Skill description 자동 트리거 매칭 강도 Unknown

- **Claude:** description 텍스트와 사용자 발화 자동 매칭이 강함.
- **Codex:** Codex의 매칭 강도는 실측되지 않음 (`<skills_instructions>`로 자동 주입은 확인됐으나 트리거 정확도는 모델별로 다를 수 있음).
- **완화:** 슬래시 트리거(`/<name>`)와 명령 호출(`codex exec --prompt-file`) 양쪽을 모두 README와 AGENTS.md에 명시. 단일 트리거 경로에 의존하지 않음.

## 10. multi_agent feature flag 가시 표면 부재

- **Codex:** `codex features list`에서 `multi_agent=stable&true`이지만 1차 도구 표면(`Task` 같은 도구)은 미발견 (`01 §2.9`, `§4`).
- **현재 대응:** MCP team server로 우회.
- **추후:** 가시 표면이 노출되면 (예: `codex mcp-server` 의 sub-resource 등) 본 하네스를 재포팅하여 폴링 오버헤드 제거.
