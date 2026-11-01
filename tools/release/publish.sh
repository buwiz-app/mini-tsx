#!/usr/bin/env bash
# tools/release/publish.sh — build this mini app for this machine and write
# a protocol 1.0 package's GitHub release assets to dist/release/ (flat
# names, as GitHub's are):
#   hello-mini-app-<os>-<arch>     the binary; installed at bin/hello-mini-app
#   <plugin id>.manifest.json      the signed manifest it serves
#                                  (buwiz://manifest); installed beside it
#   plugin.json                    package/plugin.json with buwiz.files and
#                                  buwiz.binaries filled in (each sha256) by
#                                  the SDK's `package` command, its buwiz
#                                  block signed
# Both are signed with the publisher key from the login Keychain
# (`buwiz-broker sign-manifest`, then `sign-manifest --block buwiz`): macOS
# asks twice. Only the owner runs it so; an agent uses --key-file.
#
# With --publish it then creates the release v<version> on GitHub (gh), or,
# when it exists (another platform's run), adds this platform's binary to
# its plugin.json, signs that again and uploads both.
#
#   --publish          create or extend the GitHub release
#   --prerelease       mark a new release as a pre-release: the Bot's install
#                      from the repo URL reads the latest release, which
#                      skips pre-releases (for a coordinated switch)
#   --key-file <path>  sign with a seed file instead (a throwaway key for
#                      local checks; never with --publish)
#   --trust <file>     check the result as the Bot does (`buwiz-broker
#                      manifest verify` and `manifest package`) against
#                      this trust store
# Env:
#   BUWIZ_BROKER_BIN   buwiz-broker from a buwiz-bot checkout (broker/)
#   GH_REPO            owner/repo to publish to (default: gh's repo here)
set -euo pipefail

BIN_NAME="hello-mini-app"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO/dist/release"
PUBLISH=0
PRERELEASE=()
KEY_FILE=
TRUST=
die() { echo "publish: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=1 ;;
    --prerelease) PRERELEASE=(--prerelease) ;;
    --key-file) KEY_FILE="${2:?--key-file needs a path}"; shift ;;
    --trust) TRUST="${2:?--trust needs a file}"; shift ;;
    *) die "usage: publish.sh [--publish [--prerelease]] [--key-file <seed file>] [--trust <trust.json>]" ;;
  esac
  shift
done
[ "$PUBLISH" = 1 ] && [ -n "$KEY_FILE" ] && die "--publish signs with the Keychain key only"
[ "$PUBLISH" = 1 ] || [ ${#PRERELEASE[@]} = 0 ] || die "--prerelease goes with --publish"
BROKER="${BUWIZ_BROKER_BIN:-}"
[ -n "$BROKER" ] && [ -x "$BROKER" ] || die "set BUWIZ_BROKER_BIN to a buwiz-broker build (buwiz-bot's broker/)"

case "$(uname -s)" in Darwin) OS=macos ;; Linux) OS=linux ;; *) die "unsupported OS $(uname -s)" ;; esac
case "$(uname -m)" in arm64 | aarch64) ARCH=aarch64 ;; x86_64) ARCH=x86_64 ;; *) die "unsupported arch $(uname -m)" ;; esac
PLATFORM="$OS-$ARCH"
BIN_ASSET="$BIN_NAME-$PLATFORM"

cd "$REPO"
if [ "$PUBLISH" = 1 ] && [ -n "$(git status --porcelain)" ]; then die "the tree has changes: release a commit"; fi
COMMIT="$(git rev-parse HEAD)"
bun run --silent build >/dev/null
rm -rf "$OUT" && mkdir -p "$OUT"
cp "dist/$BIN_NAME" "$OUT/$BIN_ASSET"
BIN="$OUT/$BIN_ASSET"

# the unsigned manifest, under the release key id, and each TSX app's source
"$BIN" manifest >"$OUT/manifest.json"
read -r PLUGIN_ID VERSION KEY_ID < <(node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(m.id, m.version, m.publisher.key_id)' "$OUT/manifest.json")
MANIFEST="$PLUGIN_ID.manifest.json"
TAG="v$VERSION"
APP_ARGS=()
for id in $(node -e 'for (const a of JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).apps ?? []) if (a.entry) console.log(a.id)' "$OUT/manifest.json"); do
  "$BIN" app-source "$id" >"$OUT/app-$id.tsx"
  APP_ARGS+=(--app "$id=$OUT/app-$id.tsx")
done
if [ -n "$KEY_FILE" ]; then SIGN=(--key-file "$KEY_FILE"); HOW="(a key file)"; else SIGN=(--keychain "$KEY_ID"); HOW="(approve the Keychain prompt)"; fi

echo "signing the manifest with $KEY_ID $HOW" >&2
"$BROKER" sign-manifest "$OUT/manifest.json" "${SIGN[@]}" ${APP_ARGS[@]+"${APP_ARGS[@]}"} --out "$OUT/$MANIFEST"
rm "$OUT/manifest.json" "$OUT"/app-*.tsx

PUBLISHED=()
EXISTS=0
if [ "$PUBLISH" = 1 ]; then
  GH_REPO="${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
  if gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    # another platform's run: keep the platforms the release already has
    EXISTS=1
    gh release download "$TAG" -R "$GH_REPO" -p plugin.json -O "$OUT/published.plugin.json" --clobber
    PUBLISHED=(--published "$OUT/published.plugin.json")
    echo "$TAG exists: adding $PLATFORM to its plugin.json" >&2
  fi
fi
# the SDK's package command: buwiz.files and buwiz.binaries, each sha256
"$BIN" package package/plugin.json "$OUT" "$PLATFORM" ${PUBLISHED[@]+"${PUBLISHED[@]}"}
rm -f "$OUT/published.plugin.json"

echo "signing plugin.json's buwiz block with $KEY_ID $HOW" >&2
"$BROKER" sign-manifest "$OUT/plugin.unsigned.json" --block buwiz "${SIGN[@]}" --out "$OUT/plugin.json"
rm "$OUT/plugin.unsigned.json"

if [ -n "$TRUST" ]; then
  # as the Bot's install checks them: the served manifest's signature, then
  # plugin.json's block for this platform
  node - "$OUT" "$MANIFEST" "$TRUST" "$PLATFORM" "$BROKER" <<'JS'
const { execFileSync } = require("node:child_process");
const { readFileSync } = require("node:fs");
const [out, manifest, trustFile, platform, broker] = process.argv.slice(2);
const trust = JSON.parse(readFileSync(trustFile, "utf8"));
const op = (name, req) => {
  let text;
  try {
    text = execFileSync(broker, ["manifest", name], { input: JSON.stringify(req), encoding: "utf8" });
  } catch (e) {
    text = String(e.stdout || e.stderr || e.message);
  }
  const a = JSON.parse(text || "{}");
  if (!a.ok) throw new Error(`buwiz-broker manifest ${name}: ${text.trim()}`);
  return a.value;
};
try {
  const served = op("verify", { text: readFileSync(`${out}/${manifest}`, "utf8"), trust }).manifest;
  const p = op("package", { text: readFileSync(`${out}/plugin.json`, "utf8"), trust, platform });
  for (const k of ["id", "short", "version"]) if (served[k] !== p[k]) throw new Error(`the served manifest's ${k} is ${served[k]}; plugin.json's is ${p[k]}`);
  console.error(`checked: ${p.id} ${p.version} for ${platform}, binary ${p.binary.asset}, files ${p.files.map((f) => f.path).join(", ")}`);
} catch (e) {
  console.error(`publish: ${e.message}`);
  process.exit(1);
}
JS
fi
echo "dist/release: $PLUGIN_ID $TAG for $PLATFORM at $COMMIT" >&2

[ "$PUBLISH" = 1 ] || { echo "dry run: --publish creates the release" >&2; exit 0; }
if [ "$EXISTS" = 1 ]; then
  gh release upload "$TAG" -R "$GH_REPO" --clobber "$OUT/$BIN_ASSET" "$OUT/plugin.json"
else
  gh release create "$TAG" -R "$GH_REPO" --target "$COMMIT" ${PRERELEASE[@]+"${PRERELEASE[@]}"} --title "$BIN_NAME $VERSION" \
    --notes "$PLUGIN_ID $VERSION, a Buwiz mini app (protocol 1.0). Install it by asking the Buwiz Bot's agent to install https://github.com/$GH_REPO" \
    "$OUT/$BIN_ASSET" "$OUT/$MANIFEST" "$OUT/plugin.json"
fi
echo "published $TAG" >&2
