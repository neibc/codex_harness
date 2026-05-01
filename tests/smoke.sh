#!/usr/bin/env bash
# codex_harness — smoke test (placeholder)
#
# Phase C 빌더가 이 파일을 실제 검증 스크립트로 갱신합니다.
# 통과 기준은 .claude/skills/codex-plugin-packaging/references/smoke-test.md 참조.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "[smoke.sh placeholder]"
echo ""
echo "이 파일은 Phase C 빌드 전입니다. 실제 검증을 실행하려면 먼저 빌드하세요:"
echo ""
echo "  Claude Code 측:"
echo "    /codex-harness-orchestrator codex 하네스 빌드해줘"
echo ""
echo "빌드가 끝나면 이 스크립트가 다음을 검증합니다:"
echo "  1. codex --version"
echo "  2. codex mcp list (team 항목 존재)"
echo "  3. 프롬프트 파일 존재"
echo "  4. 팀 서버 stdio handshake"
echo "  5. codex exec dry-run"
echo ""
exit 0
