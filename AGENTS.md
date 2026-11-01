# AGENTS.md

A Buwiz Bot mini app in TypeScript (protocol 2.0), made from the `buwiz-app/mini-tsx` template. The SDK
(`@buwiz/sdk`, from `buwiz-app/buwiz-sdk`, pinned by commit in `package.json`) does the protocol; this repo holds
the manifest (`src/manifest.ts`), the tools (`src/tools.ts`) and the screens (`apps/`, embedded by
`src/apps.ts`). Bun runs it and `bun build --compile` releases it. `docs/guide.md` is the reference for every part.

Skills, by task: `add-tool`, `add-command` (commands and scopes), `add-screen`, `release`.

## Invariants

1. **The manifest declares everything.** A tool a screen calls is in that app's `permissions.tools`; a resolve or
   routine query names a read-only tool; a routine's write is in its `writes`. `tests/manifest.test.ts` runs the
   SDK's quick check; conformance runs the Bot's full one.
2. **Tools start with the manifest's `short` and `_`**, and say `readOnly: true` unless they change data.
3. **Screens are sandboxed TSX.** A screen imports only `nsh`, `nsh/base` and `buwiz`, gets data only through
   `buwiz.call`, and gives every color a `dark:` variant. Its source is served exactly as `src/apps.ts` embeds it,
   so the manifest's fingerprint always matches.
4. **Tickets, not identifiers.** A subject leaves the process only as a ticket. A tool refuses a ticket it did not
   issue (P1); a ticket's title never reveals its subject.
5. **Text without secrets.** No subject data and never a key in a message, title or log (P4, P9). Side effects sit
   behind explicit arguments, so a call with `{}` changes nothing (P5).
6. **One version, one signature.** Any change to the manifest or a screen raises `version` in `package.json`.
   Tests sign with a throwaway test key id (`hello-test-01`); only the owner signs a release with the release key,
   from the Keychain. Agents never touch the Keychain.
7. **One protocol version.** No shims for older protocol names or versions.
8. **No detached setters.** A screen passes a signal setter wrapped: `onChange={(v) => x.set(v)}`, never
   `onChange={x.set}`; the kit calls `p.onChange(v)`, so a detached `set` loses `this`.
   `tools/no-detached-setters.sh` checks `apps/`.

## Gates

`tools/check-all.sh` passes before every commit: `bun run check` (oxlint, oxfmt, tsc),
`tools/no-detached-setters.sh`, `bun test`, and `tools/bot/conformance.sh`, which needs a buwiz-bot checkout in
`BUWIZ_BOT_DIR` (`docs/guide.md` section 7).
`SKIP_BOT=1` skips conformance and fails the run, so a skip never reads as a pass. Use `bun`, not npm or npx; the
toolchain is Oxc (oxlint, oxfmt) and tsc.
