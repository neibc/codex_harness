#!/usr/bin/env bash
# codex_harness — smoke test
#
# 통과 기준: codex CLI 설치 + mcp-team-server/dist/index.js 빌드 완료 상태에서
# 1~6은 PASS, 7은 옵션. 빌드 미수행 시 [5]에서 안내 메시지.
#
# 근거: _workspace/03_translation_table.md §10.4, smoke-test.md.

set -euo pipefail

HERE="$(cd "$(dirname "$0")"/.. && pwd)"
cd "$HERE"

PASS=0
FAIL=0

pass() { printf "  \033[32mPASS\033[0m %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf "  \033[33mWARN\033[0m %s\n" "$1"; }
info() { printf "  ----  %s\n" "$1"; }

echo "[1/7] codex CLI 존재"
if command -v codex >/dev/null 2>&1; then
  pass "codex --version: $(codex --version 2>/dev/null || echo unknown)"
else
  warn "codex not in PATH — Codex CLI 미설치 환경. 일부 단계는 스킵됩니다."
fi

echo "[2/7] 매니페스트 / 메타파일 존재"
for f in \
  ".codex-plugin/plugin.json" \
  ".agents/plugins/marketplace.json" \
  ".mcp.json" \
  "hooks/hooks.json" \
  "AGENTS.md" \
  "LIMITATIONS.md" \
  "README.md" \
  "LICENSE"; do
  if [ -f "$HERE/$f" ]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

echo "[3/7] plugin.json 필수 필드 (jq 가능 시)"
PLUGIN_JSON="$HERE/.codex-plugin/plugin.json"
if command -v jq >/dev/null 2>&1; then
  for k in name version description skills hooks mcpServers license; do
    if [ "$(jq -r --arg k "$k" 'has($k)' "$PLUGIN_JSON")" = "true" ]; then
      pass "plugin.json has key: $k"
    else
      fail "plugin.json missing key: $k"
    fi
  done
else
  # node fallback
  if command -v node >/dev/null 2>&1; then
    if node -e "const m=require('$PLUGIN_JSON'); for(const k of ['name','version','description','skills','hooks','mcpServers','license']){if(!(k in m)){console.error('missing:',k);process.exit(1)}}"; then
      pass "plugin.json has all required keys (node check)"
    else
      fail "plugin.json missing required keys"
    fi
  else
    warn "neither jq nor node available — skipping plugin.json field check"
  fi
fi

echo "[4/7] skills/ + agents/ 트리"
test -f "$HERE/skills/harness/SKILL.md" && pass "skills/harness/SKILL.md exists" || fail "skills/harness/SKILL.md missing"
for ref in agent-design-patterns.md orchestrator-template.md team-examples.md \
           skill-writing-guide.md skill-testing-guide.md qa-agent-guide.md; do
  if [ -f "$HERE/skills/harness/references/$ref" ]; then
    pass "skills/harness/references/$ref"
  else
    fail "skills/harness/references/$ref missing"
  fi
done
for a in codex-internals-analyst claude-harness-cartographer primitive-translator \
         codex-plugin-builder codex-harness-qa; do
  if [ -f "$HERE/agents/$a.md" ]; then
    pass "agents/$a.md"
  else
    fail "agents/$a.md missing"
  fi
done

echo "[5/7] mcp-team-server 빌드 산출물"
DIST="$HERE/mcp-team-server/dist/index.js"
if [ -f "$DIST" ]; then
  pass "mcp-team-server/dist/index.js exists"
else
  warn "mcp-team-server/dist/index.js 미빌드. 다음을 실행하세요:"
  warn "  cd mcp-team-server && npm install && npm run build"
fi

echo "[6/7] tools/list 응답에 8개 도구 포함 (빌드되어 있을 때만)"
if [ -f "$DIST" ] && command -v node >/dev/null 2>&1; then
  RESP=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n' \
    | node "$DIST" 2>/dev/null \
    | head -c 16384 || true)
  if [ -z "$RESP" ]; then
    fail "tools/list 응답이 비어 있음 (빌드/런타임 에러 가능성)"
  else
    for t in team_create send_message recv_messages task_create \
             task_update task_list task_get_output team_destroy; do
      if printf '%s' "$RESP" | grep -q "\"$t\""; then
        pass "tool registered: $t"
      else
        fail "tool missing in tools/list response: $t"
      fi
    done
  fi
else
  warn "[6] 스킵 — dist/index.js 또는 node 부재"
fi

echo "[7/7] (옵션) Codex 통합 — 사용자 환경 부작용 가능, 기본 비활성화"
if [ "${CODEX_HARNESS_SMOKE_INTEGRATION:-0}" = "1" ]; then
  if command -v codex >/dev/null 2>&1; then
    info "codex mcp list (registered MCP servers):"
    codex mcp list || warn "codex mcp list failed"
  else
    warn "[7] codex CLI 부재 — 옵션 단계 스킵"
  fi
else
  info "set CODEX_HARNESS_SMOKE_INTEGRATION=1 to run codex mcp list (인스톨 부작용 가능)"
fi

echo
echo "========================================"
echo "smoke.sh: PASS=$PASS  FAIL=$FAIL"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK"
