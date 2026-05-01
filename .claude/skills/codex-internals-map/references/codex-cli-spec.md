# Codex CLI 사양 (실측 누적)

이 파일은 실측치를 쌓는 장소다. 분석 에이전트가 새 버전을 검증할 때 항목을 추가한다.

## 버전 0.125.0 (2026-05 기준)

### 서브커맨드 카탈로그

| 명령 | 설명 | 하네스 활용 |
|------|------|------------|
| `codex` | 인터랙티브 진입 | 사용자 진입점 |
| `codex exec` (alias `e`) | 비대화형 실행 | **서브 에이전트 호출의 핵심** |
| `codex review` | 비대화형 코드 리뷰 | QA 파이프라인 후보 |
| `codex login` / `logout` | 인증 관리 | 환경 setup |
| `codex mcp` | 외부 MCP 서버 등록/조회 | **MCP 팀 서버 등록 명령** |
| `codex plugin` → `marketplace` | 플러그인 마켓 관리 | 배포 채널 |
| `codex mcp-server` | Codex 자신을 MCP 서버로 노출 | 메타 통합용 (당장은 사용 안 함) |
| `codex app-server` | 실험적 앱 서버 | (하네스에서 미사용) |
| `codex app` | 데스크톱 앱 런처 | (미사용) |
| `codex completion` | 셸 자동완성 | (미사용) |
| `codex sandbox` | 격리 실행 | QA 단계에서 사용 |
| `codex debug` | 디버깅 | 트러블슈팅 |
| `codex apply` (alias `a`) | 마지막 diff 적용 | 빌드 자동화에서 사용 가능 |
| `codex resume` / `fork` | 이전 세션 재개/포크 | (하네스에서 미사용) |
| `codex cloud` | Codex Cloud 작업 (실험) | (하네스에서 미사용) |
| `codex exec-server` | 독립 exec 서비스 (실험) | 후속 빌드에서 검토 |
| `codex features` | feature flag 조회 | 진단용 |

### 옵션

- `-c key=value` — config 오버라이드 (TOML 파싱)
- `--enable <FEATURE>` / `--disable <FEATURE>` — feature flag 토글

### 미실측 항목 (TODO — 분석 에이전트가 채울 것)

- [ ] `codex exec`의 정확한 stdin/stdout 형식 (JSON streaming? plain?)
- [ ] `codex mcp add` 명령의 정확한 인자 (실행 명령, 환경변수 전달 방식)
- [ ] `codex plugin marketplace` 매니페스트 schema
- [ ] `~/.codex/prompts/` 디렉토리 존재 여부 및 슬래시 커맨드 트리거 규칙
- [ ] AGENTS.md 검색 순서 (working dir → upward → home?)
- [ ] hooks 시스템 존재 여부 (Claude Code의 settings.json hooks 같은 메커니즘)
- [ ] `codex exec`의 작업 디렉토리/sandbox 격리 기본값

각 항목은 `_workspace/01_codex_primitives.md`로 옮긴 뒤, 안정화되면 이 파일을 갱신.

## 갱신 로그

- 2026-05-02 — 초기 카탈로그 (codex 0.125.0 `--help` 출력 기반)
