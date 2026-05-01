# Codex Analyst Checklist

`codex-internals-analyst` 에이전트가 한 번의 분석에서 빠뜨리지 말 항목.

## 0. 사전

- [ ] `codex --version` 기록 (보고서 첫 줄)
- [ ] 설치 경로 확인 (`which codex`, `readlink -f`)

## 1. CLI 표면

- [ ] `codex --help` 전체 캡처
- [ ] 모든 서브커맨드 `--help` 캡처 (`exec`, `mcp`, `plugin`, `mcp-server`, `sandbox`, `apply`, `exec-server`)
- [ ] 옵션 중 `-c`(config 오버라이드), `--enable/--disable`(features) 동작 확인

## 2. 설정/저장 위치

- [ ] `~/.codex/` 트리 (config.toml, prompts/, sessions/, agents/, plugins/, mcp/ 등 하위 디렉토리)
- [ ] `AGENTS.md` 검색 규칙 (working dir 우선? upward search? home fallback?)

## 3. 플러그인 시스템

- [ ] `codex plugin marketplace` 서브커맨드 트리
- [ ] 매니페스트 형식 (`.codex-plugin/` 또는 단일 파일?)
- [ ] 마켓 등록 절차 (Git URL? 로컬 path? npm?)
- [ ] **revfactory의 Claude Code 플러그인 매니페스트와의 차이점** 정리

## 4. MCP

- [ ] `codex mcp add` 명령의 인자 (이름, 실행 커맨드, env, args)
- [ ] MCP 서버가 stdio인지 SSE인지
- [ ] Codex 측 도구 호출 정책 (자동 호출? 사용자 승인?)
- [ ] **자체 MCP 팀 서버가 등록되었을 때 prompt에서 도구 호출하는 문법**

## 5. Prompts / 슬래시 커맨드

- [ ] `~/.codex/prompts/` 또는 등가 위치 존재
- [ ] 슬래시 트리거(`/foo`)가 인터랙티브 모드에서 동작하는지
- [ ] frontmatter 지원 여부
- [ ] 프롬프트 안에서 다른 프롬프트 include 가능 여부

## 6. AGENTS.md

- [ ] 로딩 시점 (세션 시작 시 항상? 명시적 로드?)
- [ ] 우선순위 (working dir > home?)
- [ ] 토큰 한도 (잘림 정책)

## 7. Hooks

- [ ] hooks 존재 여부
- [ ] 이벤트 종류 (SessionStart, PreToolUse, PostToolUse 등)
- [ ] 미지원 시 사용자에게 알릴 폴백

## 8. exec 모드

- [ ] `codex exec` 인자/옵션
- [ ] stdin/stdout 형식 (raw text? JSON? streaming?)
- [ ] working directory / sandbox 기본값
- [ ] exit code 의미

## 9. Sandbox

- [ ] `codex sandbox` 격리 모델 (Docker? chroot? FS overlay?)
- [ ] 네트워크 정책

## 10. 미지원 / 경고

- [ ] Claude Code primitive 중 명백히 1차 primitive로 없는 것 목록
- [ ] 추정/억측 없이 "확인 안 됨"으로 표시할 항목 분리

각 항목 결과는 `_workspace/01_codex_primitives.md`의 해당 섹션에.
