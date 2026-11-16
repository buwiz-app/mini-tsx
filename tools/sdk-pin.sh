#!/usr/bin/env bash
# tools/sdk-pin.sh — print the buwiz-sdk revision this repo pins: the one
# place it is read from (tools/conformance.sh and the SDK link check in
# tools/check-all.sh call it). The revision is named in package.json and
# again in bun.lock; if they disagree it says where and fails.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
die() { echo "sdk-pin: $*" >&2; exit 1; }

# every "buwiz-sdk#<hex>" in the two files, as <file>:<line>:<revision>
REFS="$(grep -n -o 'buwiz-sdk#[0-9a-f]\{7,40\}' package.json bun.lock | sed 's/buwiz-sdk#//')"
PIN="$(sed -n 's/.*buwiz-sdk#\([0-9a-f]\{40\}\).*/\1/p' package.json)"
[ -n "$PIN" ] || die "no pinned buwiz-sdk revision (40 hex digits) in package.json"
BAD=
while IFS=: read -r file line rev; do
  case "$PIN" in "$rev"*) ;; *) BAD="$BAD  $file:$line names $rev"$'\n' ;; esac
done <<<"$REFS"
grep -q 'buwiz-sdk#' bun.lock || BAD="$BAD  bun.lock names no buwiz-sdk revision"$'\n'
[ -z "$BAD" ] || die "package.json pins $PIN, but:"$'\n'"$BAD"
printf '%s\n' "$PIN"
