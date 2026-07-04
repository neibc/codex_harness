#!/usr/bin/env bash
# codex_harness — smoke test
#
# 통과 기준: codex CLI 설치 + mcp-team-server/dist/index.js 빌드 완료 상태에서
# 1~10은 PASS, 11은 옵션. 빌드 미수행 시 [8]에서 안내 메시지.
#
# 검증 대상: Codex CLI 0.136.0+. canonical 설치 = 심링크 + codex mcp add.
#            (마켓플레이스 2단계는 codex 0.136 루트-레이아웃 미지원으로 옵트인 — LIMITATIONS #15)
# 근거: _workspace/03_translation_table.md §5(T1·T3·T13), §6, _workspace/05_qa_report.md §4.

set -euo pipefail

HERE="$(cd "$(dirname "$0")"/.. && pwd)"
cd "$HERE"

PASS=0
FAIL=0

pass() { printf "  \033[32mPASS\033[0m %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf "  \033[33mWARN\033[0m %s\n" "$1"; }
info() { printf "  ----  %s\n" "$1"; }

echo "[1/11] codex CLI 존재"
if command -v codex >/dev/null 2>&1; then
  pass "codex --version: $(codex --version 2>/dev/null || echo unknown)"
else
  warn "codex not in PATH — Codex CLI 미설치 환경. 일부 단계는 스킵됩니다."
fi

echo "[2/11] 매니페스트 / 메타파일 존재"
for f in \
  ".codex-plugin/plugin.json" \
  ".agents/plugins/marketplace.json" \
  ".mcp.json" \
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

echo "[3/11] plugin.json 필수 필드 (jq 가능 시)"
PLUGIN_JSON="$HERE/.codex-plugin/plugin.json"
if command -v jq >/dev/null 2>&1; then
  for k in name version description skills mcpServers license; do
    if [ "$(jq -r --arg k "$k" 'has($k)' "$PLUGIN_JSON")" = "true" ]; then
      pass "plugin.json has key: $k"
    else
      fail "plugin.json missing key: $k"
    fi
  done
else
  if command -v node >/dev/null 2>&1; then
    if node -e "const m=require('$PLUGIN_JSON'); for(const k of ['name','version','description','skills','mcpServers','license']){if(!(k in m)){console.error('missing:',k);process.exit(1)}}"; then
      pass "plugin.json has all required keys (node check)"
    else
      fail "plugin.json missing required keys"
    fi
  else
    warn "neither jq nor node available — skipping plugin.json field check"
  fi
fi

echo "[4/11] plugin.json 재포지셔닝 (keywords 17개 + 6패턴 description) + marketplace URL"
# keywords 17개 (T1)
if command -v node >/dev/null 2>&1; then
  KW_COUNT=$(node -e "const m=require('$PLUGIN_JSON'); console.log((m.keywords||[]).length)" 2>/dev/null || echo 0)
  if [ "$KW_COUNT" -ge 17 ]; then
    pass "plugin.json keywords >= 17 (실측 $KW_COUNT)"
  else
    fail "plugin.json keywords < 17 (실측 $KW_COUNT)"
  fi
else
  warn "node 부재 — keywords count 스킵"
fi
# description 6패턴 factory 문구 (T1)
for phrase in "team-architecture factory" "Pipeline" "Fan-out/Fan-in" "Expert Pool" "Producer-Reviewer" "Supervisor" "Hierarchical Delegation"; do
  if grep -q "$phrase" "$PLUGIN_JSON"; then
    pass "plugin.json description mentions: $phrase"
  else
    fail "plugin.json description missing: $phrase"
  fi
done
# marketplace.json owner URL 정정 (T2)
MKT_JSON="$HERE/.agents/plugins/marketplace.json"
if grep -q 'github.com/neibc/codex_harness' "$MKT_JSON" && ! grep -q 'github.com/revfactory/codex_harness' "$MKT_JSON"; then
  pass "marketplace.json websiteURL owner = neibc"
else
  fail "marketplace.json websiteURL owner 오류 (revfactory 잔존 또는 neibc 부재)"
fi

echo "[5/11] 재사용 검토 섹션 이식 확인 (T7·T8·T9)"
if grep -q '3-0. 기존 에이전트 중복 검토' "$HERE/skills/harness/SKILL.md" \
   && grep -q '4-0. 기존 스킬 중복 검토' "$HERE/skills/harness/SKILL.md"; then
  pass "SKILL.md Phase 3-0/4-0 이식됨"
else
  fail "SKILL.md Phase 3-0/4-0 누락"
fi
if grep -q '에이전트 재사용 설계' "$HERE/skills/harness/references/agent-design-patterns.md"; then
  pass "agent-design-patterns.md '에이전트 재사용 설계' 이식됨"
else
  fail "agent-design-patterns.md '에이전트 재사용 설계' 누락"
fi
if grep -q '스킬 재사용 설계' "$HERE/skills/harness/references/skill-writing-guide.md"; then
  pass "skill-writing-guide.md '스킬 재사용 설계' 이식됨"
else
  fail "skill-writing-guide.md '스킬 재사용 설계' 누락"
fi

echo "[6/11] 설치 서사 canonical=심링크 정합 (T14·T15·T16)"
# install.sh: 기본 심링크 canonical + --marketplace 옵트인
if grep -q 'MARKETPLACE_MODE=0' "$HERE/install.sh" \
   && grep -q -- '--marketplace) MARKETPLACE_MODE=1' "$HERE/install.sh"; then
  pass "install.sh 기본 심링크 canonical + --marketplace 옵트인"
else
  fail "install.sh 설치 서사 불일치 (심링크 canonical / --marketplace 옵트인 아님)"
fi
# install.sh: 마켓 실패 시 심링크 자동 폴백
if grep -q 'install_symlink_mode' "$HERE/install.sh" \
   && grep -q '자동 폴백' "$HERE/install.sh"; then
  pass "install.sh 마켓 실패 시 심링크 자동 폴백"
else
  fail "install.sh 마켓 실패 폴백 로직 누락"
fi
# LIMITATIONS #15 존재
if grep -q '## 15\.' "$HERE/LIMITATIONS.md"; then
  pass "LIMITATIONS.md #15 (마켓 루트-레이아웃 미호환) 존재"
else
  fail "LIMITATIONS.md #15 누락"
fi
# 스테일 서사 제거 확인 (T17)
if grep -q 'not active in 0.125.x' "$HERE/SECURITY.md"; then
  fail "SECURITY.md 스테일 문구 'not active in 0.125.x' 잔존"
else
  pass "SECURITY.md 스테일 문구 제거됨"
fi
if grep -q '0.125.x에서는 manual 등록이 canonical' "$HERE/mcp-team-server/README.md"; then
  fail "mcp-team-server/README.md 스테일 '0.125.x manual canonical' 잔존"
else
  pass "mcp-team-server/README.md 0.136 canonical로 갱신됨"
fi

echo "[7/11] skills/ 트리"
test -f "$HERE/skills/harness/SKILL.md" && pass "skills/harness/SKILL.md exists" || fail "skills/harness/SKILL.md missing"
for ref in agent-design-patterns.md orchestrator-template.md team-examples.md \
           skill-writing-guide.md skill-testing-guide.md qa-agent-guide.md; do
  if [ -f "$HERE/skills/harness/references/$ref" ]; then
    pass "skills/harness/references/$ref"
  else
    fail "skills/harness/references/$ref missing"
  fi
done

echo "[8/11] mcp-team-server 빌드 산출물"
DIST="$HERE/mcp-team-server/dist/index.js"
if [ -f "$DIST" ]; then
  pass "mcp-team-server/dist/index.js exists"
else
  warn "mcp-team-server/dist/index.js 미빌드. 다음을 실행하세요:"
  warn "  cd mcp-team-server && npm install && npm run build"
fi

echo "[9/11] tools/list 응답에 8개 도구 포함 (빌드되어 있을 때만)"
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
  warn "[9] 스킵 — dist/index.js 또는 node 부재"
fi

echo "[10/11] 팀/멤버 존재 검증 회귀 가드 (T19)"
# 정적 가드: tools.ts 핸들러에 검증 코드가 존재하는가
TOOLS_TS="$HERE/mcp-team-server/src/tools.ts"
if grep -q 'requireActiveTeam' "$TOOLS_TS" && grep -q 'unknown member' "$TOOLS_TS"; then
  pass "tools.ts 팀/멤버 검증 코드 존재 (requireActiveTeam + unknown member)"
else
  fail "tools.ts 팀/멤버 검증 코드 부재 — 결함 회귀 가능"
fi
# 동적 가드: 서버를 stdio 기동해 정상 라운드트립 + 잘못된 team_id/멤버 isError 확인
if [ -f "$DIST" ] && command -v node >/dev/null 2>&1; then
  if node "$HERE/tests/mcp_guard.mjs"; then
    pass "mcp_guard.mjs 5/5 (정상 라운드트립 + bad team_id/member isError)"
  else
    fail "mcp_guard.mjs 실패 — 팀/멤버 검증 회귀"
  fi
else
  warn "[10] 동적 가드 스킵 — dist/index.js 또는 node 부재 (정적 가드는 수행됨)"
fi

echo "[11/11] (옵션) Codex 통합 — 사용자 환경 부작용 가능, 기본 비활성화"
if [ "${CODEX_HARNESS_SMOKE_INTEGRATION:-0}" = "1" ]; then
  if command -v codex >/dev/null 2>&1; then
    info "codex mcp list (registered MCP servers):"
    codex mcp list || warn "codex mcp list failed"
  else
    warn "[11] codex CLI 부재 — 옵션 단계 스킵"
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
