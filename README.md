# mini-tsx

A template for a Buwiz Bot mini app in TypeScript, with TSX screens, released as a package around one compiled
binary. It speaks Buwiz Mini App Protocol 1.0. Fork it, run one command to name it, and build: the protocol comes
from [buwiz-sdk](https://github.com/buwiz-app/buwiz-sdk), so the template holds only what is yours.

```sh
bun install
tools/new.sh notes "Notes"     # name it: app.buwiz.notes, notes_* tools, /notes
bun test                       # your tests, through the SDK's harness
tools/check-all.sh             # every gate, the Bot's conformance runner included
bun run build                  # dist/notes-mini-app, the binary the Bot spawns
tools/release/publish.sh       # run by Buwiz after review: the release package (docs/guide.md section 10)
```

The example app, Hello, has one tool (`hello_greet`), a `/hello` command and an `@hello:friend` scope (one resolve
tool, `hello_resolve`), and one screen (`apps/home.tsx`).

| Path              | What                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| `src/`            | The mini app: `manifest.ts`, `tools.ts`, `apps.ts` (the screens, embedded), the `Plugin` in `plugin.ts` |
| `apps/`           | The screens, one `.tsx` file each                                                                       |
| `package/`        | `plugin.json`, the package template a release fills and signs                                           |
| `tests/`          | Tests                                                                                                   |
| `tools/`          | `new.sh`, `check-all.sh`, `no-detached-setters.sh`, `bot/conformance.sh`, `release/publish.sh`          |
| `docs/guide.md`   | The walkthrough: tools, commands and scopes, screens, routines, tests, release                          |
| `.claude/skills/` | Skills for coding agents: add a tool, a command or scope, a screen; release                             |

Want native Rust screens, or Rust throughout? Use [buwiz-app/mini-rs](https://github.com/buwiz-app/mini-rs). Native
screens are for first-party (`app.buwiz`) mini apps; every other mini app uses TSX screens.

Anyone can build a mini app, but the Bot installs only mini apps Buwiz has signed: once submission opens, you send yours to Buwiz, which
reviews it and signs it. The way to submit isn't open yet ([docs/guide.md](docs/guide.md) section 10).

## License

Apache License 2.0 ([LICENSE](LICENSE); `NOTICE` holds the copyright line). A mini app made from this template
starts under the same license: change `LICENSE`, `NOTICE` and the license field if yours differs.
