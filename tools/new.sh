#!/usr/bin/env bash
# tools/new.sh — make this template your mini app: rename Hello everywhere.
#
# Usage: tools/new.sh <short> "<Title>" [<plugin id>]
#   short      2 to 16 of a-z and 0-9, starting with a letter: the tool
#              prefix (<short>_…), the command (/<short>) and the binary
#              (<short>-mini-app)
#   Title      the name users see (1 to 60 characters)
#   plugin id  reverse DNS (default app.buwiz.<short>, Buwiz's own namespace;
#              the id for any other mini app is settled when you submit it)
#
# It renames the package, ids, tool names and docs, writes a short README
# for your app, then installs and tests. Run it once, on a fresh copy;
# commit the result.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

die() { echo "new: $*" >&2; exit 2; }
[ $# -ge 2 ] && [ $# -le 3 ] || die "usage: tools/new.sh <short> \"<Title>\" [<plugin id>]"
SHORT="$1"
TITLE="$2"
ID="${3:-app.buwiz.$SHORT}"
[[ "$SHORT" =~ ^[a-z][a-z0-9]{1,15}$ ]] || die "short must be 2 to 16 of a-z and 0-9, starting with a letter"
case "$SHORT" in buwiz | app | chat | mcp | nsh | all | hello) die "short $SHORT is reserved" ;; esac
[ -n "$TITLE" ] && [ "${#TITLE}" -le 60 ] || die "the title must be 1 to 60 characters"
[[ "$ID" =~ ^[a-z][a-z0-9-]{0,62}(\.[a-z][a-z0-9-]{0,62}){2,7}$ ]] || die "plugin id $ID is not reverse DNS (e.g. app.buwiz.$SHORT)"
grep -q '"name": "hello-mini-app"' package.json || die "already renamed (package.json is not hello-mini-app)"
TYPE="$(printf '%s' "${SHORT:0:1}" | tr a-z A-Z)${SHORT:1}"

# every tracked text file but this script and the lockfile
git ls-files -z | grep -zv -e '^tools/new.sh$' -e '^bun.lock$' | while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  TITLE="$TITLE" ID="$ID" SHORT="$SHORT" TYPE="$TYPE" perl -pi -e '
    s/export const TITLE = "Hello";/export const TITLE = "$ENV{TITLE}";/g;
    s/app\.buwiz\.hello\b/$ENV{ID}/g;
    s/\bhello(?=-(mini|test)\b)/$ENV{SHORT}/g;
    s/\bhello_/$ENV{SHORT}_/g;
    s/([@\/"`])hello\b/$1$ENV{SHORT}/g;
    s/\bHello\b/$ENV{TYPE}/g;
  ' "$f"
done

cat >README.md <<README
# $TITLE

A mini app for the Buwiz Bot: plugin \`$ID\`, made from
[buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx). [docs/guide.md](docs/guide.md) is the walkthrough;
\`tools/check-all.sh\` runs every gate.
README

bun install --silent
bun test
echo "new: this is now $TITLE ($ID): $SHORT-mini-app, tools ${SHORT}_*, /$SHORT. Review the diff, then commit."
