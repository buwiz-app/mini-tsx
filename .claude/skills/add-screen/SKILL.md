---
name: add-screen
description: Add or change a screen of this mini app (an app in the manifest) — a full-screen view or an inline chat card, in TSX. Use for anything the user sees.
---

# Add a screen

1. **Write it** as `apps/<id>.tsx`: a default-exported component that imports only `nsh`, `nsh/base` and
   `buwiz`, reads `buwiz.props`, gets data only through `buwiz.call?.(<tool>, …)`, sizes itself from
   `buwiz.viewport()` (an inline card reports its height with `buwiz.fit`), and gives every color a `dark:`
   variant. No `fetch`, no `localStorage`, no other import. `docs/guide.md` section 5 has the pattern; the Bot's
   bridge reference has every method.
2. **Embed it**: import it as text in `src/apps.ts` and add it to `APPS`.
3. **Declare it** in `src/manifest.ts` `apps`: `id`, `title`, `description`, `...tsx("<id>", APPS.<id>)`, a
   `props` schema (tickets as strings of at most 30 characters), `placement`, `inline` when inline, and
   `permissions` granting exactly what it uses: the tools it calls, plus `open`, `attach`, `pick_file`,
   `storage`, `copy` or `preview`.
4. **Test** that its tools answer as that app: `h.app(<id>, <tool>, …)` in `tests/tools.test.ts`.

Done when `tools/check-all.sh` passes, with every `APP-01` to `APP-04` row and this app's `BRG-03` rows passing in
conformance.
