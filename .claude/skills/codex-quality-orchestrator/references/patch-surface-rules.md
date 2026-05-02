# Patch Surface Rules — 4가지 정비 표면의 정확한 경계

prompt-engineer가 정비안을 적용할 때 따라야 할 룰. **revfactory 원본 추상화 보존**(LIMITATIONS.md #11)이 최상위 원칙.

## 허용 표면 1 — Frontmatter 강화

**무엇을 수정 가능한가:**
- description 본문 — 트리거 키워드 추가, 후속 작업 키워드 보강 ("재실행", "업데이트", "다시")
- description 적극성 강화 (revfactory가 권하는 "pushy" 스타일)
- `tools:` 키 추가/수정 (사람용 안내 — Codex는 자동 인식 안 함이지만 사용자/협업자에게 의도 전달)
- `metadata:` 키에 short-description, priority, pathPatterns, promptSignals 등

**무엇을 수정 불가:**
- ❌ name 변경 (트리거 키워드와 직결, 호환성 깨짐)
- ❌ description의 의미를 바꾸는 변경 (도메인 변경 = 새 스킬)

**예시:**
```yaml
# Before
description: "PDF 처리 스킬"
# After (trigger 키워드 보강 OK)
description: "PDF 파일 읽기, 텍스트/표 추출, 병합/분할/회전, 워터마크, OCR 등 모든 PDF 작업. .pdf 파일 언급 시 또는 PDF 산출물 요청 시 반드시 사용. '다시', '재실행', '업데이트'도 트리거."
```

## 허용 표면 2 — Codex 환경 박스

**위치**: SKILL.md 본문의 phase 옆 또는 끝, references 본문 내 적절한 위치.

**형식**:
```markdown
> **Codex 환경 안내**: <Codex-특성 한계 + 사용자 우회 발화 예>
```

**원칙:**
- 본문 자체는 변경 X (revfactory 추상화 보존)
- 박스는 **Codex-특성 한계만** 안내. 일반적 best practice는 박스에 넣지 않는다.
- 박스 1개당 한 가지 한계만 (가독성).

**예시:**
```markdown
> **Codex 환경 안내**: Codex(GPT-5.x)는 명시 기준 없으면 보수적으로 짧게 끝내는
> 경향이 있어, 도메인이 깊이를 요구하면 사용자가 "최종 보고서 ≥10 섹션" 같이
> 정량 요구를 명시하세요. 자세히는 LIMITATIONS.md #11 참조.
```

## 허용 표면 3 — 호출 wrapper 가이드

**위치**: SKILL.md, 에이전트 정의 .md 의 "협업" / "호출 예" 섹션.

**무엇을 수정 가능한가:**
- `codex exec` 호출 옵션 표시 (`-m`, `-s`, `-C`, `--ephemeral`, `--json`, `--add-dir`, `-o`)
- profile 사용 예 (`~/.codex/config.toml [profiles.X]`)
- stdin 주입 패턴 (`codex exec - "<task>" < agents/<name>.md`)
- 외부 MCP 등록 명령 (`codex mcp add <name> -- <cmd>`)

**무엇을 수정 불가:**
- ❌ 호출 자체를 다른 도구로 대체 (예: codex 대신 다른 CLI)
- ❌ revfactory의 도구 추상화(Agent, TeamCreate 등) 자체를 본문에 강제 변경

**예시:**
```bash
# Before
codex exec --prompt-file agents/builder.md "<task>"   # 잘못된 옵션
# After
codex exec - "<task>" < agents/builder.md             # stdin 주입 (정확한 호출)
codex exec --json --ephemeral -m gpt-5.3-codex -s workspace-write \
  -C _workspace/build/ - "<task>" < agents/builder.md  # 풀옵션
```

## 허용 표면 4 — AGENTS.md 라우팅/도구 표 정밀화

**위치**: `AGENTS.md`.

**무엇을 수정 가능한가:**
- 트리거 키워드 보강
- 에이전트 호출 라우팅 표 (작업 의도 → 에이전트 매핑) 정밀화
- MCP 도구 표 도구명/인자/출력 명세
- 변경 이력 한 행 추가

**무엇을 수정 불가:**
- ❌ 도메인/하네스 이름 변경
- ❌ 에이전트 추가/삭제 (이건 별도 사이클이 필요한 큰 변경, prompt-engineer 권한 밖)

## 거부 표면 (사용자 명시 승인 없으면 절대 변경 X)

다음은 LIMITATIONS.md #11에서 명시 거부 결정한 표면:

1. **Phase 갯수 / 순서 변경** — revfactory의 7-Phase는 추상화. 임의로 늘리거나 합치면 호환성/회귀 어려움.
2. **"에이전트 팀 기본값" 같은 정책 변경** — revfactory 원본의 명시 정책. 변경 X.
3. **변증법/methodology critique 본문 강제 주입** — revfactory가 의도적으로 추상화한 영역(도메인 깊이는 모델 자율 판단). 강제 주입은 원본 의도 변형.
4. **Phase 완료 정량 조건 강제** — 같은 이유. 사용자 측 명시 발화로만 보강.

위 4가지가 필요하다는 가설이 나오면, prompt-engineer는 정비안을 적용하지 말고 **사용자 승인 필요 항목**으로 분리해 보고. 사용자가 명시 동의하면 그제서야 적용.

## 적용 후 검증

모든 정비 후 즉시:
1. `bash tests/smoke.sh` 1회 — 통과 필수
2. `codex debug prompt-input "x" | grep harness:` — 활성화 유지 확인
3. 변경된 파일에 lint 도구 있으면 통과 확인 (markdownlint 등)

실패 시 즉시 git revert + 사유 보고.
