# Building a mini app in TypeScript

A mini app is a plugin for the Buwiz Bot: a small binary the Bot spawns, speaking MCP on stdin and stdout. It
brings **tools** (the model, screens and routines call them), **commands** (`/hello`) and **scopes**
(`@hello:friend:Ada`), **routines** (timed agent runs) and **screens** (full screen, or inline cards in the chat).
A signed **manifest** declares all of it, and the Bot trusts nothing the manifest does not declare. The rules are
[Buwiz Mini App Protocol 1.0](https://github.com/buwiz-app/buwiz-sdk/blob/main/docs/protocol-1.0.md); a 1.0 Bot
runs 1.0 plugins only.

You write what is yours: the manifest, the tools, the screens. The SDK
([buwiz-app/buwiz-sdk](https://github.com/buwiz-app/buwiz-sdk), `@buwiz/sdk/plugin`) does the protocol: MCP, the
reserved `buwiz.*` tools, session certificates, tickets, pushed account tokens, and the caller checks. The release
is a package: one compiled binary (`bun build --compile`, so users need no runtime), its signed manifest and a
signed `plugin.json`.

You can build and test a mini app freely. Before it installs in the Bot, Buwiz reviews it and signs it, so you need no
signing key of your own (section 10).

## 1. Make it yours

Click **Use this template** on GitHub (or clone it), then name your app:

```sh
bun install
tools/new.sh notes "Notes"            # plugin id app.buwiz.notes
tools/new.sh notes "Notes" com.example.notes
```

It renames the package, the plugin id, every `hello_*` tool and the `/hello` command, writes a short README, then
installs and tests. The rest of this guide calls the app Hello.

## 2. What is where

| Path              | What                                                                                                         |
| ----------------- | ------------------------------------------------------------------------------------------------------------ |
| `src/manifest.ts` | The manifest, built in code; its version is `package.json`'s                                                 |
| `package/`        | `plugin.json`, the package template: the Bot's spawn line, accounts (section 9) and the signed `buwiz` block |
| `src/tools.ts`    | The tools: `list()` (what the model sees) and `call()` (what runs)                                           |
| `src/apps.ts`     | The TSX sources, imported as text so the binary embeds them                                                  |
| `src/plugin.ts`   | `Hello`: the state (tickets, your store) and the `Plugin` that ties it together                              |
| `src/main.ts`     | One line: the SDK's command line                                                                             |
| `apps/`           | The screens, one `.tsx` file each                                                                            |
| `tests/`          | Tests, through the SDK's harness                                                                             |
| `tools/`          | `check-all.sh` (every gate), `no-detached-setters.sh`, `bot/conformance.sh`, `release/publish.sh`, `new.sh`  |

The binary's command line comes from the SDK:

```
bun run mcp                                   what the Bot runs, from source
dist/hello-mini-app mcp                       the same, compiled (bun run build)
dist/hello-mini-app manifest [--key-id <id>]  the unsigned manifest, for signing
dist/hello-mini-app app-source <id>           a screen's source, exactly as served
dist/hello-mini-app package <plugin.json> <out> <os>-<arch> [--published <plugin.json>]
                                              fill a release's plugin.json, to sign (section 10)
```

## 3. Add a tool

1. In `tools.ts`, name it `hello_<verb>` (every tool starts with the manifest's `short` and `_`), and add it to
   `list()`: a description the model reads to choose it, a JSON Schema for its arguments, and `readOnly: true`
   unless it changes data.
2. Handle it in `call()`. Answer `ok({…})`, or `fail(code, message)` with a code such as `not_found` or
   `invalid_args` and a message the user can read. `call` may be `async`.
3. A screen that calls it lists it in its app's `permissions.tools` in `manifest.ts`; the model can call any tool.
4. Test it in `tests/` through the harness (section 7).

The SDK refuses a call before it reaches you when the caller may not make it (section 8). What it cannot know is
your data: check every ticket an argument carries against your own subjects, and refuse one you did not issue.

## 4. Add a command or a scope

A command (`/hello ada`) and a scope (`@hello:friend:ada`) each name a **resolve tool**, a read-only tool the Bot
calls with `{kind: "command" | "scope", name, value, complete, context}`. It answers one `result`:

| `result`  | Fields                                                              | Means                                               |
| --------- | ------------------------------------------------------------------- | --------------------------------------------------- |
| `choices` | `choices: [{label, detail?, value}]` (20 at most; `value` a ticket) | completions while the user types (`complete: true`) |
| `open`    | `app`, `props?`, `title`, `placement?`                              | open one of your screens                            |
| `token`   | `ticket`, `title`                                                   | the scope token, standing for a subject             |
| `prompt`  | `text`                                                              | commands only: starter text for the message field   |
| `error`   | `message`                                                           | nothing matched                                     |

Add the entry to `commands` or `scopes` in `manifest.ts`, and handle its `kind` and `name` in the resolve tool.
A scope with `attach: true` must answer `token` for every `value` it offered as a choice.

## 5. Add a screen

A screen is one TSX file in `apps/`, run by the Bot in a sandbox:

```tsx
import { signal, Text, View } from "nsh";
import { buwiz } from "buwiz";

export default function Home() {
  const line = signal("…");
  buwiz.call?.("hello_greet", { ticket: buwiz.props.ticket as string }).then(
    (r) => line.set(String(r.greeting)),
    (e) => line.set(e.retryable ? "Busy, try again" : `Could not load (${e.code})`),
  );
  return <Text class="text-[#1c1c1c] dark:text-[#f5f5f5]">{line()}</Text>;
}
```

- It imports only `nsh`, `nsh/base` and `buwiz`, and reaches nothing else: no `fetch`, no storage but
  `buwiz.storage`. Its data comes from your tools through `buwiz.call`.
- Its default export is the component the Bot mounts. It reads `buwiz.props` and sizes itself from
  `buwiz.viewport()`; an inline card reports its height with `buwiz.fit(height)` and may use `buwiz.actions`,
  `buwiz.meta` and `buwiz.settle` for the Bot's own card chrome. A card with `inline.wait_ready: true` keeps its
  placeholder until it calls `buwiz.ready()` (or 3 seconds pass).
- Every color has a `dark:` variant: the Bot renders in its own light or dark theme.
- A method whose permission the manifest does not grant is absent, hence `buwiz.call?.(…)`.

Then register it:

1. Import it as text in `src/apps.ts` and add it to `APPS`.
2. Add its entry to `apps` in `manifest.ts`, spreading `tsx("<id>", APPS.<id>)` (the entry, mime, sdk and
   fingerprint), with `props`, `placement`, `inline` (when inline) and `permissions`: exactly the tools it calls,
   plus `open`, `attach`, `pick_file`, `storage`, `copy` or `preview` if it uses them.

`@buwiz/sdk/app` types the `buwiz` bridge; `nsh` is untyped until nsh's own types ship in the SDK. The Bot's
[bridge reference](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/bridge.md) has every
method, its permission, its errors and its limits; [performance.md](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/performance.md)
has how to keep cards fast.

## 6. Add a routine

A routine is a timed agent run: every `every_s` seconds the Bot calls your read-only `query` tool, and when its
`field` has text, the model runs `prompt` with your read-only tools. A tool that changes data runs in that turn
only if the routine lists it in `writes`, and the user approves those writes at install. Add it to `routines` in
`manifest.ts`; the harness's `routine()` calls a tool as that routine's turn.

## 7. Test

```sh
bun test                       # your tests
tools/check-all.sh             # every gate: oxlint, oxfmt, tsc, detached setters, tests, conformance
```

`Harness` from `@buwiz/sdk/plugin` is a provisioned server: call your tools the way the Bot does.

```ts
const h = await Harness.start(new Hello());
await h.agent("hello_greet"); // as the model
await h.resolve("hello_resolve", { kind: "scope", value: "ada" });
await h.app("home", "hello_greet", { ticket }); // as the home screen, from a certified open
await h.routine("tidy", "hello_tidy"); // in a routine's turn
```

Each resolves to the result's `structuredContent`, or rejects with a `ToolError` (`code`, `message`).

**Conformance** runs the Bot's own checker against your compiled binary: the manifest's grammar and limits, the
signature, each screen's source (it compiles, imports only what it may, reaches no network), the reserved tools,
sessions, signed calls and resolves. It needs a checkout of the Bot:

```sh
git clone https://github.com/buwiz-bot/buwiz-bot && (cd buwiz-bot/server && npm ci)
BUWIZ_BOT_DIR=$PWD/buwiz-bot tools/bot/conformance.sh
```

It signs with a throwaway key under a test key id, never the release key.

## 8. What the SDK checks, and what is yours

Before your tool runs, the SDK has made sure that:

- nothing runs before the Bot provisions the plugin's key;
- a screen's call comes from an open the plugin certified, and names a tool in that screen's `permissions.tools`;
- a resolve and a routine's query only read;
- a routine's turn only reads, or calls a write the routine declares.

It also answers `buwiz.account.set` and `buwiz.account.clear`, and keeps the tokens they push in memory (section 9).

Yours:

- **Tickets, not identifiers.** Outside your process a subject is a ticket (`tkt_…`): in tool results, props,
  tokens and titles. `buwiz.ticket.resolve` answers a title, never the subject.
- **Check what you are handed.** Every ticket, every id: refuse what you did not issue (P1).
- **Side effects behind explicit arguments** (P5), so a probe with `{}` changes nothing.
- **Text without secrets.** A message, title or log carries no subject data and never the key (P4, P9). A tool
  that throws answers `internal`; its error reaches stderr only under `BUWIZ_PLUGIN_DEBUG=1`.

The full rules: the Bot's [security checklist](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/security.md)
and [manifest reference](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/manifest.md).

## 9. Accounts

A mini app that calls a service as the person (Google, or any OAuth issuer) declares the account in
`package/plugin.json`'s `buwiz.accounts`. The Bot signs the person in and pushes the access token to the plugin;
the plugin never asks, and the token never reaches the model, a screen or a log (protocol 1.0 section 20).

```json
"accounts": [{ "id": "google", "provider": "google", "label": "Google account", "scopes": ["https://www.googleapis.com/auth/drive.file"] }]
```

A tool reads the token from its caller. Pass `caller` through from `Hello.call` (the `Plugin`'s third argument),
and answer `accountRequired` when there is none, so the Bot asks the person to sign in:

```ts
import { type Caller, type Result, accountRequired } from "@buwiz/sdk/plugin";

async function files(caller: Caller): Promise<Result> {
  const google = caller.account("google"); // the default sign-in, else any live one
  if (!google) return accountRequired("google");
  const r = await fetch("https://www.googleapis.com/drive/v3/files", { headers: { Authorization: google.authorization() } });
  …
}
```

Never log a token or put it in an answer. In tests, sign in and out as the Bot does, with a synthetic token:

```ts
const h = await Harness.start(new Hello());
await h.signIn("google", "<token>"); // the default sign-in
// h.signInWith({ account: "google", label: "work", access_token: "<token>" }) for another label, scopes or expiry
await h.signOut("google");
```

## 10. Release

Only Buwiz signs a release, and the Bot installs only mini apps Buwiz has signed. You build and check your mini app,
then submit it to Buwiz, which reviews it and signs it. The way to submit isn't open yet.

A 1.0 release is a **package** on GitHub releases (protocol 1.0 sections 7 and 8): `plugin.json` with a signed
`buwiz` block, the signed manifest (`<plugin id>.manifest.json`, installed at `bin/` beside the binary, where the
binary finds it) and one binary per platform (`hello-mini-app-<os>-<arch>`, installed at `bin/hello-mini-app`).

1. Raise `version` in `package.json`, the one place it lives: any change to the manifest or a screen needs a new
   version and new signatures. The manifest takes the version from `package.json`, and the SDK's `package` command
   fills `package/plugin.json`'s `version` and the `buwiz` block's protocol, id, short, version and publisher from
   the signed manifest, so the template carries none of them.
2. `tools/check-all.sh`.
3. Submit the mini app to Buwiz for review. The way to submit isn't open yet.
4. After review, Buwiz approves the plugin id under the release key in the Bot's trust store:
   `{ "id": "app.buwiz.hello", "publisher_key_id": "gc-2026-01" }`.
5. Buwiz signs the release, with `BUWIZ_BROKER_BIN` set to a `buwiz-broker` build from the Bot:
   ```sh
   tools/release/publish.sh                          # dry run: dist/release, signed from the Keychain
   tools/release/publish.sh --publish --prerelease   # the release v<version>, as a GitHub pre-release
   tools/release/publish.sh --publish                # the release v<version>, the one the Bot installs
   ```
   It compiles the binary, signs the manifest (`buwiz-broker sign-manifest`), fills `package/plugin.json` with the
   SDK's `package` command (the version and the block's protocol, id, short and publisher from the signed manifest,
   `buwiz.files` and `buwiz.binaries` each with its sha256), and signs the block
   (`buwiz-broker sign-manifest --block buwiz`). Run on another platform, `--publish` adds that platform's binary to
   the existing release. The Bot installs from a repository's latest release, which skips pre-releases: publish a
   pre-release first when a switch is coordinated, then mark it the latest.

To check a package without the release key, sign with a throwaway seed and a trust store that maps the release key
id to it: `tools/release/publish.sh --key-file <seed> --trust <trust.json>` runs the Bot's own checks
(`buwiz-broker manifest verify` and `manifest package`). A package signed this way is only a check: the Bot installs what Buwiz has signed. Sign and notarize the binary as you would any macOS
executable.
