#!/usr/bin/env bash
# tools/new.sh — make this repo your mini app: rename Hello everywhere.
#
# Usage: tools/new.sh <short> --id <plugin id> --publisher <publisher id> "<publisher name>"
#                     [--title "<Title>"] [--description "<text>"] [--first-party] [--no-build]
#   (what each part allows is in the usage this prints on a refusal)
#
# There is no default id or publisher. A new plugin has no release key id
# until Buwiz assigns one at submission: tools/release/publish.sh takes it
# from KEY_ID. It renames the package, ids, tool names and docs, writes the
# new README and NOTICE, then installs, formats and tests. Last, it removes
# itself and tools/test-new.sh, which describe this repo as it is now and
# are no use in your app. Run it once, on a fresh copy; commit the result.
#
# What it writes of yours (title, publisher name, description) goes in after
# every rename of the template's own words, so a "Hello" you wrote stays.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage() {
  cat >&2 <<'USAGE'

  tools/new.sh invoices \
    --id com.acme.invoices \
    --publisher com.acme "Acme"

  <short>               2 to 16 of a-z and 0-9, starting with a letter
  --id <plugin id>      3 to 8 dot-separated labels, each 1 to 63 of a-z, 0-9 and -,
                        starting with a letter; at most 255 characters in all;
                        under a domain you own (com.acme.invoices)
  --publisher <id> "<name>"
                        your publisher id: dot-separated labels of a-z, 0-9 and -;
                        the first 2 to 63 characters and starting with a letter,
                        each other 1 to 62 (acme and com.acme are both valid);
                        and the name users see, 1 to 80 characters (not Buwiz)
  --title "<Title>"     the app's name users see, 1 to 60 characters
                        (default: the short, capitalised)
  --description "<text>"  what the app does, 1 to 300 characters (default: the title)
  --first-party         Buwiz's own new plugins only (the app.buwiz namespace)
  --no-build            rename only: skip the install, the formatting and the tests

  Titles, names and descriptions may not contain a quote, a backslash, a
  backtick, a $ or a control character.
USAGE
  exit 2
}
fail() { echo "new.sh: $*" >&2; usage; }

SHORT= ID= PUB_ID= PUB_NAME= TITLE= DESC= FIRST_PARTY=0 BUILD=1
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --id) [ $# -ge 2 ] || fail "--id needs a plugin id"; ID="$2"; shift 2 ;;
    --publisher)
      [ $# -ge 3 ] && [[ "$3" != -* ]] || fail "--publisher needs a publisher id and a name"
      PUB_ID="$2"; PUB_NAME="$3"; shift 3 ;;
    --title) [ $# -ge 2 ] || fail "--title needs a title"; TITLE="$2"; shift 2 ;;
    --description) [ $# -ge 2 ] || fail "--description needs a text"; DESC="$2"; shift 2 ;;
    --first-party) FIRST_PARTY=1; shift ;;
    --no-build) BUILD=0; shift ;;
    -*) fail "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || fail "one short name, not ${#POS[@]}"
if [ -z "$ID" ] || [ -z "$PUB_ID" ]; then fail "give your plugin an id and a publisher:"; fi
[ ${#POS[@]} -eq 1 ] || fail "give your plugin a short name:"
SHORT="${POS[0]}"

# the SDK's grammars (docs/manifest.md; protocol 1.0 section 4; the validator
# in packages/conformance/src/grammar.mjs and v1/manifest.mjs). tools/test-new.sh
# checks these against the SDK's own.
[[ "$SHORT" =~ ^[a-z][a-z0-9]{1,15}$ ]] || fail "short $SHORT is not 2 to 16 of a-z and 0-9, starting with a letter"
case "$SHORT" in buwiz | app | chat | mcp | nsh | all | office | skill | routine | bot | hello) fail "short $SHORT is reserved" ;; esac
[ "${#ID}" -le 255 ] && [[ "$ID" =~ ^[a-z][a-z0-9-]{0,62}(\.[a-z][a-z0-9-]{0,62}){2,7}$ ]] ||
  fail "plugin id $ID is not 3 to 8 dot-separated labels of 1 to 63 of a-z, 0-9 and -, each starting with a letter (at most 255 characters), e.g. com.acme.$SHORT"
# the host's own prefixes: the SDK refuses any id that starts with them
case "$ID" in buwiz.* | com.buwiz.bot*) fail "plugin id $ID is in the namespace of Buwiz Bot itself" ;; esac
[[ "$PUB_ID" =~ ^[a-z][a-z0-9-]{1,62}(\.[a-z0-9-]{1,62})*$ ]] ||
  fail "publisher id $PUB_ID is not dot-separated labels of a-z, 0-9 and -: the first 2 to 63 characters, starting with a letter, each other 1 to 62 (e.g. acme or com.acme)"

TYPE="$(printf '%s' "${SHORT:0:1}" | tr a-z A-Z)${SHORT:1}"
TITLE="${TITLE:-$TYPE}"
text_ok() { # <what> <value> <min> <max>: they end up in source string literals, JSON and TOML
  [ "${#2}" -ge "$3" ] && [ "${#2}" -le "$4" ] || fail "$1 must be $3 to $4 characters"
  case "$2" in
    *[\"\\\`\$]* | *[[:cntrl:]]*) fail "$1 may not contain a quote, a backslash, a backtick, a \$ or a control character" ;;
  esac
}
text_ok "the title" "$TITLE" 1 60
text_ok "the publisher name" "$PUB_NAME" 1 80
DESCRIPTION="${DESC:-$TITLE}"
text_ok "the description" "$DESCRIPTION" 1 300

# app.buwiz is Buwiz's own, and only Buwiz can sign for it
if [ "$FIRST_PARTY" = 1 ]; then
  [ "$PUB_ID" = app.buwiz ] && [[ "$ID" == app.buwiz.* ]] || fail "--first-party takes the id app.buwiz.<name> and the publisher app.buwiz"
  RELEASE_KEY_ID="gc-2026-01"
  KEY_SENTENCE=""
else
  if [[ "$ID" == app.buwiz.* || "$PUB_ID" == app.buwiz || "$PUB_ID" == app.buwiz.* ]]; then
    fail "app.buwiz is Buwiz's own namespace and only Buwiz can sign for it: use your own (--first-party is for Buwiz's own new plugins)"
  fi
  # nor Buwiz's name
  case "$(printf '%s' "$PUB_NAME" | tr '[:upper:]' '[:lower:]')" in
    buwiz | "buwiz "*) fail "the publisher name $PUB_NAME is Buwiz's: use your own (--first-party is for Buwiz's own new plugins)" ;;
  esac
  RELEASE_KEY_ID="unassigned"
  KEY_SENTENCE=" Its source holds no release key id: Buwiz assigns one at submission (section 10)."
fi
grep -q '"name": "hello-mini-app"' package.json || fail "already renamed (package.json is not hello-mini-app)"

# 1. the README, NOTICE and the guide's first section, written with
# placeholders (%%NAME%%) that step 2 fills in after every rename
cat >README.md <<'README'
# %%TITLE%%

A mini app for the Buwiz Bot by %%PUB_NAME%%: plugin `%%ID%%`, made from
[buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx). [docs/guide.md](docs/guide.md) is the walkthrough;
`tools/check-all.sh` runs every gate.

## License

Apache License 2.0 ([LICENSE](LICENSE); `NOTICE` holds the copyright line). Change both, and the license field in
`package.json`, if yours differs.
README
cat >NOTICE <<'NOTICE'
%%TITLE%%
Copyright %%YEAR%% %%PUB_NAME%%
NOTICE
SECTION1="$(
  cat <<'SECTION'
This repo is the mini app `%%ID%%`, published by %%PUB_NAME%%.%%KEY_SENTENCE%% The rest of this guide calls the app
Hello.
SECTION
)"
SECTION1="$SECTION1" perl -0pi -e 's/\n## 1\. Make it yours\n.*?(?=\n## 2\. )/\n## 1. Your app\n\n$ENV{SECTION1}\n/s; s/, `new\.sh`//' docs/guide.md
grep -q '^## 1\. Your app$' docs/guide.md || { echo "new.sh: could not rewrite section 1 of docs/guide.md" >&2; exit 1; }
# the gate script's step for this repo's own tests of new.sh is no use in your app
perl -ni -e 'print unless m{tools/(new|test-new)\.sh}' tools/check-all.sh

# 2. every tracked text file: the template's own words are renamed or made
# placeholders, then every placeholder takes its value in one pass, so a
# value of yours is never itself renamed
git ls-files -z | grep -zv -e '^tools/new.sh$' -e '^tools/test-new.sh$' | while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  TITLE="$TITLE" ID="$ID" PUB_ID="$PUB_ID" PUB_NAME="$PUB_NAME" DESCRIPTION="$DESCRIPTION" RELEASE_KEY_ID="$RELEASE_KEY_ID" \
    SHORT="$SHORT" TYPE="$TYPE" KEY_SENTENCE="$KEY_SENTENCE" YEAR="$(date +%Y)" perl -pi -e '
    BEGIN { our %v = map { $_ => $ENV{$_} } qw(TITLE ID PUB_ID PUB_NAME DESCRIPTION RELEASE_KEY_ID SHORT TYPE KEY_SENTENCE YEAR) }
    s/^(export const TITLE = )"Hello";/$1"%%TITLE%%";/;
    s/^(export const PUBLISHER_ID = )"app\.buwiz";/$1"%%PUB_ID%%";/;
    s/^(export const PUBLISHER_NAME = )"Buwiz";/$1"%%PUB_NAME%%";/;
    s/^(\s*description: )"The mini-tsx template: [^"]*"/$1"%%DESCRIPTION%%"/;
    s/^(\s*"description": )"The mini-tsx template: [^"]*"/$1"%%DESCRIPTION%%"/;
    s/^(\s*"author": \{ "name": )"Buwiz"/$1"%%PUB_NAME%%"/;
    s/\bgc-2026-01\b/%%RELEASE_KEY_ID%%/g;
    s/app\.buwiz\.hello\b/%%ID%%/g;
    s/\bhello(?=-(mini|test)\b)/%%SHORT%%/g;
    s/\bhello_/%%SHORT%%_/g;
    s/([@\/"`])hello\b/$1%%SHORT%%/g;
    s/\bHello\b/%%TYPE%%/g;
    s/%%(\w+)%%/$v{$1}/g;
  ' "$f"
done

# 3. install and format, then the SDK's own quick check of the new manifest
# (problems(), in tests/manifest.test.ts), then the tests
if [ "$BUILD" = 1 ]; then
  bun install --silent
  bun run --silent fmt # the new names change the width of the docs' tables
fi
if [ -d node_modules ]; then
  bun test tests/manifest.test.ts || { echo "new.sh: the new manifest fails the SDK's check (above)" >&2; exit 1; }
else
  echo "new.sh: the manifest is not checked yet: bun install, then bun test" >&2
fi
[ "$BUILD" = 0 ] || bun test

# 4. last: this script and its test are about the repo you started from
git rm -q -f tools/new.sh tools/test-new.sh
echo "new.sh: created $ID ($TITLE, by $PUB_NAME): $SHORT-mini-app, tools ${SHORT}_*, /$SHORT. Review the diff, then commit."
