#!/usr/bin/env bash
# codex_harness — one-shot installer
#
# 사용법 / Usage:
#   ./install.sh                                  # 기본 설치
#   ./install.sh --skip-build                     # mcp-team-server 빌드 생략 (이미 빌드됨)
#   ./install.sh --copy                           # 심링크 대신 복사 (저장소를 옮길 예정일 때)
#   ./install.sh --no-color                       # 컬러 출력 비활성화
#
# 동작:
#   0. node + codex CLI 사전 검사
#   1. mcp-team-server 의존성 설치 + tsc 빌드 (변경 시에만)
#   2. codex mcp add team --env TEAM_STORAGE_PATH=... -- node ...
#   3. ~/.codex/skills/harness 심볼릭 링크 (또는 --copy)
#   4. 활성화 검증 (codex mcp list + codex debug prompt-input)
#   5. 다음 액션 안내 (자연어 트리거 발화 출력)
#
# 사전 요구:
#   - node >= 18
#   - codex CLI 0.125.0+ (https://github.com/openai/codex)

set -euo pipefail

SKIP_BUILD=0
USE_COPY=0
USE_COLOR=1

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --copy) USE_COPY=1 ;;
    --no-color) USE_COLOR=0 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [ "$USE_COLOR" = "1" ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else
  G=""; Y=""; R=""; B=""; D=""; N=""
fi

step() { printf "${B}==>${N} %s\n" "$1"; }
ok()   { printf "  ${G}✓${N} %s\n" "$1"; }
warn() { printf "  ${Y}!${N} %s\n" "$1"; }
fail() { printf "  ${R}✗${N} %s\n" "$1" >&2; exit 1; }
hint() { printf "  ${D}%s${N}\n" "$1"; }

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"

# ---------- 0. 사전 검사 ----------
step "0/5 사전 검사 / Prerequisites"

if ! command -v node >/dev/null 2>&1; then
  fail "node 명령을 찾을 수 없습니다. Node.js 18+ 설치 후 다시 시도하세요."
fi
NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 18 ]; then
  fail "Node.js $NODE_MAJOR 감지 — 18+ 필요. nvm/volta로 업그레이드 후 다시 시도하세요."
fi
ok "node $(node --version)"

if ! command -v codex >/dev/null 2>&1; then
  fail "codex CLI를 찾을 수 없습니다. https://github.com/openai/codex 에서 설치 후 재시도."
fi
CODEX_VER=$(codex --version 2>/dev/null | awk '{print $NF}')
ok "codex $CODEX_VER"
case "$CODEX_VER" in
  0.12[5-9].*|0.1[3-9][0-9].*|[1-9].*) ;;
  *) warn "codex $CODEX_VER — 본 플러그인은 0.125.0+로 검증됨. 동작은 가능하나 미실측." ;;
esac

# ---------- 1. mcp-team-server 빌드 ----------
step "1/5 MCP 팀 서버 빌드 / Build mcp-team-server"

if [ ! -d "mcp-team-server" ]; then
  fail "$REPO/mcp-team-server 디렉토리가 없습니다. 저장소가 손상되었거나 잘못된 경로입니다."
fi

if [ "$SKIP_BUILD" = "1" ]; then
  warn "--skip-build 지정 — 빌드 생략"
else
  cd mcp-team-server
  if [ ! -d node_modules ] || ! diff -q package-lock.json node_modules/.package-lock.json >/dev/null 2>&1; then
    ok "npm install (의존성 변경 감지)"
    npm install --silent
  else
    ok "node_modules 최신"
  fi
  ok "tsc 빌드"
  npm run build --silent
  cd "$REPO"
fi

if [ ! -f "mcp-team-server/dist/index.js" ]; then
  fail "mcp-team-server/dist/index.js 생성 실패. 'cd mcp-team-server && npm install && npm run build' 수동 실행 후 재시도."
fi

# ---------- 2. MCP 팀 서버 등록 ----------
step "2/5 MCP 팀 서버 등록 / Register MCP team server"

if codex mcp list 2>/dev/null | grep -q '^team\b'; then
  ok "team MCP 서버 이미 등록됨 (재등록 생략)"
  hint "다른 경로로 재등록하려면: codex mcp remove team 후 본 스크립트 재실행"
else
  if codex mcp add team \
       --env "TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite" \
       -- node "$REPO/mcp-team-server/dist/index.js" >/dev/null 2>&1; then
    ok "codex mcp add team 완료"
  else
    fail "codex mcp add team 실패. 'codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite -- node $REPO/mcp-team-server/dist/index.js' 수동 실행 후 진행하세요."
  fi
fi

# ---------- 3. 스킬 활성화 ----------
step "3/5 스킬 활성화 / Activate skill"

mkdir -p "$HOME/.codex/skills"

TARGET="$HOME/.codex/skills/harness"
SOURCE="$REPO/skills/harness"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  CURRENT=$(readlink "$TARGET" 2>/dev/null || echo "directory")
  if [ "$CURRENT" = "$SOURCE" ]; then
    ok "이미 활성화됨: $TARGET → $SOURCE"
  else
    warn "$TARGET 가 다른 경로($CURRENT)를 가리킵니다."
    hint "교체하려면: rm -f \"$TARGET\" && ./install.sh"
    fail "활성화 중단 — 사용자 결정 필요"
  fi
else
  if [ "$USE_COPY" = "1" ]; then
    cp -R "$SOURCE" "$TARGET"
    ok "스킬 복사: $TARGET"
    hint "저장소 변경 시 ./install.sh --copy 또는 cp -R 재실행 필요"
  else
    ln -sfn "$SOURCE" "$TARGET"
    ok "심링크: $TARGET → $SOURCE"
    hint "저장소 편집은 즉시 반영됨 (다음 codex 세션부터)"
  fi
fi

# ---------- 4. 활성화 검증 ----------
step "4/5 활성화 검증 / Verify"

if codex mcp list 2>/dev/null | grep -qE '^team\s+node\s+'; then
  ok "codex mcp list 에 team 등록 확인"
else
  warn "codex mcp list 출력에 team 없음 — codex 재시작 후 다시 확인하세요"
fi

if codex debug prompt-input "x" 2>/dev/null | grep -q 'harness:harness'; then
  ok "harness 스킬이 prompt-input에 등장 — 활성화 완료"
else
  warn "harness 스킬이 prompt-input에 안 보임. 'codex' 재시작 또는 다음으로 수동 검증:"
  hint "codex debug prompt-input \"x\" 2>/dev/null | grep -o 'harness:[^\"]*' | head -1"
fi

# ---------- 5. 다음 액션 안내 ----------
step "5/5 완료 / Done"

cat <<EOF

${G}${B}✓ codex_harness 설치 완료${N}

${B}이제 codex 안에서 자연어로 트리거하세요:${N}

  ${B}codex${N}
  > 하네스를 구성해줘
  > build a harness for an e-commerce backend

${D}(슬래시 명령 /<name>은 Codex 0.125.x의 본 install 경로에서는 노출되지 않습니다.
 자연어 발화로만 활성화됩니다 — 자세한 이유는 README의 "트리거" 섹션 참조.)${N}

${B}비대화형 / CI:${N}
  codex exec --prompt-file skills/harness/SKILL.md "<요청>"

${B}업데이트:${N}
  ./bin/update.sh

${B}제거:${N}
  README의 "제거 / Uninstall" 섹션 참조

EOF
