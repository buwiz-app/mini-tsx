---
name: release
description: Prepare a release of this mini app for Buwiz to review and sign — version bump, gates, a package checked with a throwaway key. Use when asked to release, ship, publish or install a new build.
---

# Prepare a release

1. **Raise the version**, semver, in `package.json`, the one place it lives: the manifest takes it from there, and
   the SDK's `package` fills `package/plugin.json`'s version from the signed manifest. Any change to the manifest or
   a screen since the last release needs it.
2. **Pass every gate:** `tools/check-all.sh`, conformance included, with no row failing beyond what `AGENTS.md`
   names as known.
3. **Check the package** without the release key: in a fresh 0700 temp dir outside the repo, make a throwaway seed
   (`node <buwiz-bot>/server/sdk/mini-app/bin/buwiz-plugin-test.mjs --keygen <dir>/test.key`) and a trust store
   mapping the release key id to its public key with the plugin approved, then
   `BUWIZ_BROKER_BIN=<buwiz-broker> tools/release/publish.sh --key-file <dir>/test.key --trust <dir>/trust.json`.
   It must end with `checked:`. Delete the temp dir and `dist/release/` after: that package is not the release.
4. **Hand over.** The mini app goes to Buwiz for review; the way to submit isn't open yet. After review Buwiz takes
   the steps of `docs/guide.md` section 10: the trust entry, then `tools/release/publish.sh --publish` (add
   `--prerelease` for a coordinated switch), which signs from the login Keychain. Only Buwiz runs it; an agent never
   runs `--publish`, never signs with the release key and never touches the Keychain.

Done when the gates pass, the throwaway package checks, and the new version is ready to submit.
