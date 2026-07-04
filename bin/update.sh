#!/usr/bin/env bash
# codex_harness — one-shot update script
#
# 사용법 / Usage:
#   ./bin/update.sh                 # 일반 업데이트
#   ./bin/update.sh --check         # 변경사항만 확인 (실제 update 안 함)
#   ./bin/update.sh --skip-build    # mcp-team-server 빌드 생략
#   ./bin/update.sh --no-color      # 컬러 출력 비활성화
#
# 동작:
#   1. git fetch + 변경 사항 요약
#   2. fast-forward git pull (충돌 시 중단)
#   3. mcp-team-server 의존성/빌드 갱신 (변경된 경우만)
#   4. 활성화 상태 검증 (codex mcp list + codex debug prompt-input — canonical 심링크 기준)
#   5. (옵션) --marketplace 로 등록한 마켓이 있으면 codex plugin marketplace upgrade
#
# 필요 시: cron / launchd / GitHub Actions로 주기 실행 가능 (README 참조).

set -euo pipefail

CHECK_ONLY=0
SKIP_BUILD=0
USE_COLOR=1

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --no-color) USE_COLOR=0 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [ "$USE_COLOR" = "1" ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; Y=""; R=""; B=""; N=""
fi

step() { printf "${B}==>${N} %s\n" "$1"; }
ok()   { printf "  ${G}✓${N} %s\n" "$1"; }
warn() { printf "  ${Y}!${N} %s\n" "$1"; }
fail() { printf "  ${R}✗${N} %s\n" "$1" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# ---------- 1. git fetch + diff summary ----------
step "1/5 git fetch + 변경 요약"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "$REPO 가 git 저장소가 아닙니다."
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch --quiet origin "$CURRENT_BRANCH"

LOCAL=$(git rev-parse "@")
REMOTE=$(git rev-parse "@{u}" 2>/dev/null || echo "$LOCAL")
BASE=$(git merge-base "@" "@{u}" 2>/dev/null || echo "$LOCAL")

if [ "$LOCAL" = "$REMOTE" ]; then
  ok "이미 최신 ($CURRENT_BRANCH @ $(git rev-parse --short HEAD))"
  if [ "$CHECK_ONLY" = "1" ]; then exit 0; fi
elif [ "$LOCAL" = "$BASE" ]; then
  COUNT=$(git rev-list --count "$LOCAL".."$REMOTE")
  ok "$COUNT 개 신규 커밋:"
  git log --oneline "$LOCAL".."$REMOTE" | head -10 | sed 's/^/    /'
elif [ "$REMOTE" = "$BASE" ]; then
  warn "로컬이 origin 보다 앞서 있습니다 — push 또는 정리 필요. update 중단."
  exit 1
else
  warn "로컬과 origin이 분기되었습니다 — 수동 merge/rebase 필요. update 중단."
  exit 1
fi

if [ "$CHECK_ONLY" = "1" ]; then
  step "변경 파일 (--check)"
  git diff --stat "$LOCAL"..."$REMOTE" | head -30
  exit 0
fi

# ---------- 2. git pull (fast-forward) ----------
step "2/5 fast-forward pull"
if [ "$LOCAL" != "$REMOTE" ]; then
  if [ -n "$(git status --porcelain)" ]; then
    warn "작업 트리에 uncommitted 변경이 있습니다:"
    git status --short | sed 's/^/    /'
    fail "stash 또는 commit 후 다시 시도하세요."
  fi
  git pull --ff-only --quiet origin "$CURRENT_BRANCH"
  ok "pull 완료 → $(git rev-parse --short HEAD)"
fi

# ---------- 3. mcp-team-server 빌드 ----------
step "3/5 mcp-team-server 빌드"
if [ "$SKIP_BUILD" = "1" ]; then
  warn "--skip-build 지정 — 빌드 생략"
elif [ ! -d "mcp-team-server" ]; then
  warn "mcp-team-server 디렉토리 없음 — 건너뜀"
else
  cd mcp-team-server
  # package-lock.json 변경 또는 dist/ 부재 시에만 npm install
  if [ ! -d node_modules ] || ! diff -q package-lock.json node_modules/.package-lock.json >/dev/null 2>&1; then
    ok "npm install (의존성 변경 감지)"
    npm install --silent
  else
    ok "node_modules 최신 (npm install 생략)"
  fi
  ok "tsc 빌드"
  npm run build --silent
  cd "$REPO"
fi

# ---------- 4. 활성화 검증 ----------
step "4/5 활성화 검증"
if ! command -v codex >/dev/null 2>&1; then
  warn "codex CLI 부재 — 활성화 검증 생략"
else
  # canonical(심링크 + codex mcp add) 설치에서는 team MCP가 codex mcp list에 등장한다.
  # (--marketplace 옵트인은 codex 0.136 루트-레이아웃 미지원으로 실패/폴백 — LIMITATIONS #15)
  if codex mcp list 2>&1 | grep -q '^team\b'; then
    ok "codex mcp list: team 등록됨"
  else
    warn "codex mcp list에 team 없음 — canonical(심링크) 설치라면 재등록 필요:"
    warn "    codex mcp add team --env TEAM_STORAGE_PATH=\$HOME/.codex/teams.sqlite \\"
    warn "      -- node \"$REPO/mcp-team-server/dist/index.js\""
  fi

  if codex debug prompt-input "x" 2>/dev/null | grep -q 'harness:harness'; then
    ok "harness 스킬 활성화 확인"
  elif [ -L "$HOME/.codex/skills/harness" ] || [ -d "$HOME/.codex/skills/harness" ]; then
    warn "harness 스킬이 prompt-input에 안 보임 (심링크는 존재) — codex 재시작 후 재확인"
  else
    warn "harness 스킬이 prompt-input에 안 보임. 재활성화(canonical):"
    warn "    ln -sfn \"$REPO/skills/harness\" \"\$HOME/.codex/skills/harness\""
    warn "    또는 ./install.sh 재실행"
  fi
fi

# ---------- 5. 마켓플레이스 upgrade (옵션) ----------
step "5/5 마켓플레이스 메타데이터 갱신 (등록 + git source 일 때만)"
CONFIG="$HOME/.codex/config.toml"
if ! command -v codex >/dev/null 2>&1; then
  ok "codex CLI 부재 — 스킵"
elif [ ! -f "$CONFIG" ] || ! grep -q '^\[marketplaces\.codex-harness-marketplace\]' "$CONFIG" 2>/dev/null; then
  ok "마켓플레이스 미등록 — 스킵"
elif awk '/^\[marketplaces\.codex-harness-marketplace\]/{f=1;next} /^\[/{f=0} f && /^source_type/' "$CONFIG" | grep -q '"local"'; then
  ok "로컬 source 마켓 (이 저장소 자체) — marketplace upgrade 불필요"
  hint "canonical 설치(심링크)는 skills/AGENTS 변경이 다음 codex 세션에 자동 반영됩니다."
  hint "(--marketplace 옵트인은 codex 0.136 루트-레이아웃 미지원 — LIMITATIONS #15)"
else
  if codex plugin marketplace upgrade codex-harness-marketplace >/dev/null 2>&1; then
    ok "git/url source 마켓 메타데이터 갱신"
  else
    warn "마켓 upgrade 실패 — 무시 가능 (스킬 활성화에는 영향 없음)"
  fi
fi

printf "\n${G}${B}✓ update 완료${N}\n"
