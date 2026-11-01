#!/usr/bin/env bash
# tools/check-all.sh — every gate: oxlint, oxfmt, tsc, detached setters, tests,
# then the Bot's conformance runner (tools/bot/conformance.sh, which needs
# BUWIZ_BOT_DIR).
# SKIP_BOT=1 skips conformance, and the run then says it did not pass.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n== %s\n' "$*"; }

step "bun install"
bun install --frozen-lockfile --silent
step "oxlint, oxfmt, tsc"
bun run --silent check
step "no detached setters (apps/*.tsx)"
tools/no-detached-setters.sh
step "bun test"
bun test

if [ "${SKIP_BOT:-0}" = 1 ]; then
  printf '\nconformance SKIPPED: not every gate ran\n'
  exit 1
fi
step "conformance (the Bot's buwiz-plugin-test)"
tools/bot/conformance.sh

printf '\nall gates passed\n'
