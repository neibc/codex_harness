---
name: claude-codex-translation
description: Claude Code 하네스 자산을 Codex CLI 형식으로 변환하는 패턴과 매핑 규칙을 제공한다. SKILL.md → Codex prompt 변환, 에이전트 정의 변환, CLAUDE.md → AGENTS.md 변환, frontmatter 필드 처리, 슬래시 커맨드 트리거 변환을 다룬다. 하네스 포팅, 스킬 변환, "이 Claude 자산을 Codex에서 어떻게 표현하지?" 류의 질문에서 반드시 사용. 매핑 결정이 필요할 때 가장 먼저 호출할 스킬.
---

# Claude → Codex Translation

Claude Code 하네스 자산을 **기능 손실을 명시하면서** Codex 형식으로 옮기는 패턴 모음.

## 0. 변환 전 점검

1. 원본 자산 분류: SKILL / agent definition / CLAUDE.md / hook config / settings.
2. 자산이 사용하는 Claude 전용 호출 패턴(`Agent` 도구, `TeamCreate`, `SendMessage`, `TaskCreate`, `subagent_type`, `Skill` 호출) grep.
3. 분류된 호출을 매핑 테이블(`references/mapping-table.md`)에 대조.

## 1. SKILL.md → Codex prompt 파일

```
.claude/skills/<name>/SKILL.md   →   prompts/<name>.md (또는 ~/.codex/prompts/<name>.md)
.claude/skills/<name>/references/   →   prompts/<name>.references/  (상대경로 유지)
```

### Frontmatter 처리

| Claude SKILL frontmatter | Codex prompt 처리 |
|---|---|
| `name` | 파일명으로 사용 (frontmatter 보존) |
| `description` | Codex가 슬래시 커맨드로 노출 시 description으로 사용. 보존. |
| `allowed-tools`, `model`, 기타 Claude 전용 키 | Codex가 무시 — 보존하되 본문에 영향 없음 |

### 본문 변환 규칙

- "Skill 도구로 X를 호출"  → "`codex exec --prompt-file prompts/X.md` 호출"
- "Agent 도구로 서브 에이전트 호출" → "`codex exec --prompt-file agents/X.md --working-dir _workspace/agent-X/`"
- "TeamCreate / SendMessage / TaskCreate" → MCP 팀 서버 도구 호출 형식 (`team-emulation-mcp` 스킬 참조)
- "subagent_type=Explore" → 명시적 "읽기 전용 에이전트" 지시문으로 풀어서 작성
- 슬래시 커맨드 표기 `/foo` → Codex 슬래시 트리거 가능 시 그대로, 아니면 "`codex` 인터랙티브에서 `/foo` 또는 `codex exec --prompt-file prompts/foo.md`"

## 2. 에이전트 정의 파일

```
.claude/agents/<name>.md   →   agents/<name>.md
                              + AGENTS.md에 한 줄 등록
```

- 파일 본문은 거의 그대로 옮김. 단 다음만 손봄:
  - `tools:` frontmatter — Codex가 인식하는 도구명으로 매핑(또는 안내문으로 풀어서)
  - `model:` — Codex의 모델 선택 메커니즘이 다르므로 본문에 "권장 모델: …"으로 표기
  - 협업 섹션의 "팀 모드 / 서브 에이전트 모드" — Codex 측 등가 표현으로 변환 (각각 "MCP 팀 서버 사용" / "`codex exec` 서브프로세스")

## 3. CLAUDE.md → AGENTS.md

- 파일명만 바꿔도 90% 동작. 단:
  - "Claude Code", "/cmd", "Skill 도구" 등 Claude 전용 명사 치환
  - 트리거 규칙: "X를 요청 시 `<orchestrator-skill>` 스킬을 사용" → "X를 요청 시 `codex exec --prompt-file prompts/<orchestrator>.md` 호출, 또는 `/orchestrator` 슬래시 트리거"
- 변경 이력 테이블은 그대로 유지

## 4. 슬래시 커맨드 트리거

Codex의 슬래시 커맨드 지원 여부에 따라 분기:

- **지원 시:** prompts/<name>.md 파일을 두면 `/<name>`으로 트리거됨
- **미지원/제한 시:** README에 명시 호출 명령어를 안내, AGENTS.md의 트리거 규칙도 명령어로 작성

분석 에이전트가 실측한 결과를 `_workspace/01_codex_primitives.md`에서 확인.

## 5. Hooks

- Codex가 hooks 시스템을 지원하면 settings.json hook 정의를 동등 형식으로 옮김
- 미지원 시: shell wrapper 스크립트(`hooks/<event>.sh`)를 만들고 사용자가 `codex` 호출을 wrapper로 대체하도록 README에 안내
- 절대로 "변환했다"고 거짓말하지 말 것 — 미지원이면 명확히 명시

## 6. 변환 거절 사례

| 원본 | 거절 사유 | 권장 대안 |
|------|----------|----------|
| Claude의 `WebSearch` 도구 호출 | Codex에 등가 빌트인 없음 | MCP web-search 서버를 별도로 등록하라고 안내 |
| `TaskOutput` (Claude 내부 task 결과 조회) | 1:1 대응 없음 | MCP 팀 서버에 `task_get_output` 도구 추가 |
| Claude Code 빌트인 `Plan` 에이전트 타입 | 1차 primitive 없음 | "계획 수립 전용 prompt"를 별도 파일로 |

## 7. 변환 후 검증

각 변환된 파일은 다음을 만족해야 한다:
1. **명시적 호출 가능** — 사용자가 어떤 명령으로 트리거하는지 README에 한 줄로 적혀 있음
2. **기능 손실 표시** — 변환 거절된 호출은 "⚠️ Codex 환경에서는 X 대신 Y 사용" 표기
3. **라운드트립** — 변환된 prompt를 다시 SKILL.md로 역변환했을 때 의미가 보존되는지 확인 (정신적 시뮬레이션 OK)

## 참조

- `references/mapping-table.md` — 매핑 마스터 테이블
- `references/conversion-examples.md` — Before/After 실제 변환 예시
- `references/lossy-conversions.md` — 기능 손실이 발생하는 케이스 카탈로그
