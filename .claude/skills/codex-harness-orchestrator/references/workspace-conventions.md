# `_workspace/` 디렉토리 규칙

## 표준 트리

```
_workspace/
├── 01_codex_primitives.md         # Phase A 산출
├── 02_claude_primitives.md        # Phase A 산출
├── 03_translation_table.md        # Phase B 산출
├── 04_build_log.md                # Phase C 산출 (stub/TODO 목록)
├── 05_qa_report.md                # Phase D 산출
├── _archive/                      # 이전 버전 보관
│   ├── 01_codex_primitives_v0.123.md
│   └── ...
├── _errors/                       # 실패 시 stderr 캡처
│   └── <ts>_<phase>.md
└── _team_messages/                # 팀 모드 디버깅용 메시지 로그 (선택)
```

## 아카이브 정책

- 새 입력으로 전체 재실행 시 → `_workspace/` 통째로 `_workspace_prev_<ts>/`로 이동
- 부분 재실행 시 → 해당 산출물만 `_archive/<filename>_<ts>.md`로 이동 후 새로 생성
- 7일 이상 된 archive는 사용자에게 정리 제안 (자동 삭제 금지)

## 명명 규칙

- `<NN>_<artifact>.md` — phase 순서 번호로 시작
- `_<특수목적>` — 언더스코어 prefix는 메인 산출물 외 보조 디렉토리
- 타임스탬프는 ISO8601 압축형: `20260502T123456`

## 사용자 수동 수정

- 사용자가 `_workspace/` 파일을 수동 수정한 경우, 오케스트레이터는 `git diff` 또는 mtime을 보고 보존 결정
- 수동 수정 흔적이 있으면 덮어쓰기 전에 사용자 확인 요청 (Auto 모드라도)

## .gitignore 권장

루트 `.gitignore`에 이미 다음이 포함되어 있다 (실측 후 보정):

```
_workspace/
_workspace_prev_*/
mcp-team-server/node_modules/
mcp-team-server/dist/
```

> 산출물 자체(`skills/`, `mcp-team-server/src/`, `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `install.sh`, `bin/`, `tests/`)는 git 커밋 대상 — 그것이 곧 배포되는 Codex 플러그인이다. 빌더의 컴파일 산출물(`mcp-team-server/dist/`)만 ignore (사용자 머신에서 install.sh가 tsc 빌드).
