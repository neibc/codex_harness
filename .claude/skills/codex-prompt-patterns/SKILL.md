---
name: codex-prompt-patterns
description: Codex(GPT-5.x)의 출력 특성을 보완하는 프롬프트/SKILL/AGENTS 패턴 카탈로그와 4가지 비침습 정비 표면(frontmatter, 환경 박스, 호출 wrapper, AGENTS.md 라우팅) 적용 가이드. prompt-engineer 에이전트가 사용. revfactory 원본 보존 원칙을 강제한다.
---

# Codex Prompt Patterns

격차 차원 → Codex 특성 가설 → 비침습 정비 표면 매핑. 4가지 표면 외 변경 거부.

## 핵심 원칙 (LIMITATIONS.md #11에서 도출)

1. revfactory 원본의 **추상화는 보존**한다. Phase 갯수/순서/추상화 강도 변경 X.
2. 정비는 **4가지 표면**에만:
   - **A. frontmatter**: description 키워드, tools, metadata
   - **B. Codex 환경 박스**: `> **Codex 환경 안내**: ...` 단락 (본문 옆 부착)
   - **C. 호출 wrapper**: `codex exec -m -s ...` 패턴 + profile 예
   - **D. AGENTS.md 라우팅/도구 표**

3. 거부 표면이 필요하면 **사용자 명시 승인** 후만 적용.

## 패턴 카탈로그 (`references/codex-pattern-catalog.md`)

격차 차원별 가설 + 정비 표면. 사이클 돌면서 검증/누적.

| 격차 차원 | Codex 특성 가설 | 정비 표면 |
|---|---|---|
| 분량 짧음 | GPT-5.x 보수성 | B. 환경 박스로 정량 분량 권고 |
| 변증법 부재 | 자율 메타 검토 안 함 | B. 환경 박스로 사용자 발화 예 |
| 인용 빈약 | WebFetch 부재 | A+C. tools: 명시 + 외부 MCP 안내 |
| 도구 호출 자율 절약 | exec 비용 인식 | B. 환경 박스로 연쇄 호출 권고 |
| 헤더 충실 살 부족 | 구조 따라가지만 자율 확장 약함 | B. 박스로 본문 정량 권고 |
| 종료 안내 누락 | 추상화 강제 부족 | B. 박스로 종료 안내 템플릿 (이미 적용) |

## 적용 절차

prompt-engineer가 정비안을 만들 때:

1. output-comparator의 격차 표 + 정성 노트 입력
2. 차원별로 카탈로그 가설 매칭
3. 각 가설에 4표면 중 어디에 적용할지 결정
4. 적용 위치(파일 + 줄 번호) 명시한 정비안 작성 (`03_hypotheses.md`)
5. 사용자 승인 받은 후 `04_changes/` 에 변경 전 사본 보존하고 적용
6. 적용 즉시 smoke + 활성화 검증 (`tests/smoke.sh` + `codex debug prompt-input`)
7. 실패 시 즉시 git revert

## 환경 박스 템플릿

```markdown
> **Codex 환경 안내**: <한계 진술>. 사용자가 <명시 발화 예> 같이 요청하면 보완됩니다.
```

예시:
```markdown
> **Codex 환경 안내**: Codex는 변증법 검토를 자율적으로 추가하지 않습니다.
> 양측 검토가 필요한 도메인이라면 "변증법 phase 추가" 또는 "양측 입장 steelman 분석"을
> 명시 요청하세요.
```

## 호출 wrapper 템플릿

```bash
# 오케스트레이터 (계획 / 추론 깊이)
codex exec -m gpt-5.5 ...

# 빌더 (코딩 특화)
codex exec --json --ephemeral -m gpt-5.3-codex -s workspace-write \
  -C _workspace/build/ - "<task>" < agents/builder.md

# 분석가 (단발 분석)
codex exec --json --ephemeral -m gpt-5.5 -s read-only \
  -C _workspace/analysis/ - "<task>" < agents/analyst.md
```

## frontmatter 강화 패턴

description에 다음 키워드를 모두 포함:
- 명시적 트리거 (`"X 해줘"`, `"Y 분석"`)
- 후속 작업 (`"다시"`, `"재실행"`, `"업데이트"`, `"보완"`)
- 도메인 키워드 (한국어 + 영어)
- 트리거 부정어 (혼동 방지)

예:
```yaml
description: "X 도메인의 Y 작업을 자동 수행. 'X 해줘', 'Y 분석', 'X 보고서' 발화 시 사용. 후속 작업도 처리: '다시', '재실행', '업데이트', '특정 부분만 보완'. Z 같이 비슷하지만 다른 도메인 요청은 트리거하지 않음."
```

## AGENTS.md 패턴

라우팅 표 정밀화:
```markdown
| 작업 의도 | 호출 명령 |
|---|---|
| API 스펙 설계 | `codex exec -m gpt-5.5 -s workspace-write - "<task>" < agents/architect.md` |
| 코딩 / 구현 | `codex exec -m gpt-5.3-codex -s workspace-write - "<task>" < agents/builder.md` |
```

MCP 도구 표 강화 (인자/출력 명세 포함).

## 거부 표면 (사용자 승인 없이 변경 X)

다음을 prompt-engineer가 정비안에 넣었다면 사용자 승인 항목으로 분리:

1. SKILL.md 본문의 Phase 갯수/순서/추상화 변경
2. "에이전트 팀 기본값" 같은 정책 문구 변경
3. 변증법/methodology critique 같은 phase를 본문에 강제 주입
4. revfactory 원본에서 그대로 옮긴 reference 문서 본문 변경

## 검증

모든 정비 후:
```bash
bash tests/smoke.sh                                                       # 통과 필수
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1   # 활성화 유지
```

실패 시 즉시 revert.
