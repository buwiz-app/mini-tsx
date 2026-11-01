#!/usr/bin/env bash
# tools/no-detached-setters.sh — reject detached signal setters in screens.
# The kit invokes callbacks as p.onChange(v), so a bare x.set loses this.
set -euo pipefail

PATTERN='=\{[A-Za-z_$][A-Za-z0-9_$.]*\.set\}'

if [ "$#" -eq 0 ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  set -- apps
fi

set +e
OUTPUT="$(grep -rnE --include='*.tsx' -e "$PATTERN" -- "$@" 2>&1)"
RC=$?
set -e

case "$RC" in
  0)
    printf '%s\n' "$OUTPUT" >&2
    printf '%s\n' 'fix: write onChange={(v) => x.set(v)}, not onChange={x.set}' >&2
    exit 1
    ;;
  1)
    exit 0
    ;;
  *)
    printf 'no-detached-setters: grep failed (exit %s)\n' "$RC" >&2
    [ -z "$OUTPUT" ] || printf '%s\n' "$OUTPUT" >&2
    exit 2
    ;;
esac
