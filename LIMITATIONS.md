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
- **완화:** OS cron + `codex exec - < <task>.md` 외부 스케줄러 사용. README에 cron 예시 안내.

## 8. 자동 컨텍스트 압축 정책 차이 Unknown

- **Claude:** 대화 길이가 한도에 다가가면 자동 요약 압축.
- **Codex:** 동등 동작 Unknown — 수동 세션 분할 또는 `codex resume`/`codex fork`로 우회 가능.
- **완화:** 오케스트레이터가 phase 사이에 산출물을 파일로 떨어뜨려 컨텍스트 의존을 최소화. `_workspace/<phase>_<artifact>.md` 컨벤션 강제.

## 9. Skill description 자동 트리거 매칭 강도 Unknown

- **Claude:** description 텍스트와 사용자 발화 자동 매칭이 강함.
- **Codex:** Codex의 매칭 강도는 실측되지 않음 (`<skills_instructions>`로 자동 주입은 확인됐으나 트리거 정확도는 모델별로 다를 수 있음).
- **완화:** 슬래시 트리거(`/<name>`)와 명령 호출(`codex exec - < <skill-or-agent>.md`) 양쪽을 모두 README와 AGENTS.md에 명시. 단일 트리거 경로에 의존하지 않음.

## 10. multi_agent feature flag 가시 표면 부재

- **Codex:** `codex features list`에서 `multi_agent=stable&true`이지만 1차 도구 표면(`Task` 같은 도구)은 미발견 (`01 §2.9`, `§4`).
- **현재 대응:** MCP team server로 우회.
- **추후:** 가시 표면이 노출되면 (예: `codex mcp-server` 의 sub-resource 등) 본 하네스를 재포팅하여 폴링 오버헤드 제거.

## 11. Output depth on Codex (모델·환경 결합 한계)

- **관측된 격차 (실측):** 같은 메타-스킬을 받고도 Codex 측 산출물이 Claude Code 측 대비 5~8배 짧은 경우가 있다.
  - `~/claudework/saju/` (Claude+Opus): 9 에이전트, 11 스킬, 10 phase, 보고서 455줄 / 54KB / 11 섹션
  - `~/codexwork/leehongjang/` (Codex+GPT-5.4): 4 에이전트, 4 스킬, 4 phase, 보고서 57줄 / 4KB / 6 섹션
  - 두 산출물 모두 본 메타-하네스(`~2,150줄 SKILL.md + references`)를 받았다.
- **원인 두 가지:**
  1. **모델 특성**: 같은 가이드를 받아도 Codex(GPT-5.4)는 Claude(Opus)보다 phase를 보수적으로 줄이고 산출물을 짧게 쓰는 경향. 메타-하네스가 의도적으로 추상화한 부분(변증법, 방법론 비평 등 도메인 깊이는 모델 자율 판단에 맡김)에서 격차가 두드러진다.
  2. **외부 자료 수집 빌트인 부재** (#3과 직접 연관): `WebSearch`/`WebFetch`가 없어 자료 수집 phase가 약화 → 후속 phase의 인용·검증·종합이 얕아지는 연쇄 효과.
- **현재 대응:**
  - SKILL.md Phase 3에 외부 MCP(`@modelcontextprotocol/server-fetch` 등) 등록 안내 추가.
  - README 트러블슈팅에 "산출물이 짧을 때 명시적으로 깊이를 요구하는 발화 예" 명시 — "변증법적 검토 phase 추가", "Phase별 정량 완료 조건", "최종 보고서 ≥N 섹션".
  - revfactory 원본을 변형하여 깊이 가이드를 강제 주입하는 것은 **거부**한다 — 원본은 의도적으로 도메인 깊이를 모델 자율 판단에 위임하는 추상화를 채택했다(검증: 원본 SKILL.md+references에서 "변증법", "devil's advocate", "methodology critique", "Phase 완료 정량 조건" 키워드가 모두 0회). 메타-스킬 변형은 호환성을 깨고 향후 회귀를 어렵게 한다.
- **사용자 측 우회 (가장 효과적):** 하네스 구성 요청 시 도메인 특화 깊이를 명시 요구. 예:
  - "변증법적 검토(devil's advocate) phase를 포함해줘"
  - "Phase별 정량 완료 조건을 명시해줘 (예: 카탈로그 ≥ 10개)"
  - "최종 보고서를 ≥ 10 섹션, ≥ 400줄로"
  - "자료 수집 에이전트의 `tools:` frontmatter에 web_search/web_fetch MCP 사용을 명시"
