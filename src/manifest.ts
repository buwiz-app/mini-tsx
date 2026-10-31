// Hello's manifest, built in code. The version is package.json's, so a
// release bumps one number, and each TSX app's fingerprint is the hash of
// the source this build serves.
//
// The field rules and limits are the Bot's
// (server/sdk/mini-app/docs/manifest.md); tools/bot/conformance.sh checks
// them all.

import { type Manifest, PROTOCOL, tsx } from "@buwiz/sdk/plugin";
import pkg from "../package.json";
import { APPS } from "./apps";
import { GREET, RESOLVE } from "./tools";

/** The plugin id. Buwiz's own mini apps are app.buwiz.<name>. */
export const ID = "app.buwiz.hello";
/** Every tool starts with hello_. */
export const SHORT = "hello";
/** The name the user sees. */
export const TITLE = "Hello";
/** The publisher key a release is signed with. Only the owner signs. */
export const RELEASE_KEY_ID = "gc-2026-01";

/** The manifest without its signature, under publisher key id `keyId`. */
export function unsigned(keyId: string): Manifest {
  return {
    protocol: PROTOCOL,
    id: ID,
    short: SHORT,
    version: pkg.version,
    title: TITLE,
    description: "The mini-tsx template: one tool, one command, one scope and one TSX screen.",
    publisher: { id: "app.buwiz", key_id: keyId, name: "Buwiz" },
    commands: [{ name: SHORT, args: "[name]", description: `Open ${TITLE}, optionally for a friend`, resolve: RESOLVE }],
    scopes: [{ name: "friend", description: "Friend by name", resolve: RESOLVE, attach: true }],
    apps: [
      {
        id: "home",
        title: TITLE,
        description: "Greets a friend.",
        // a TSX screen: entry, mime, sdk and the fingerprint of apps/home.tsx
        ...tsx("home", APPS.home),
        props: { type: "object", properties: { ticket: { type: "string", maxLength: 30 } } },
        placement: ["full", "inline"],
        inline: { width: 360, height: 160, resizable: false },
        // exactly the tools the screen calls
        permissions: { tools: [GREET] },
      },
    ],
  };
}
