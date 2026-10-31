// The manifest against the tools Hello lists. The full check is the Bot's
// conformance runner (tools/bot/conformance.sh); this is the quick one.

import { expect, test } from "bun:test";
import { fingerprint, problems } from "@buwiz/sdk/plugin";
import pkg from "../package.json";
import { APPS } from "../src/apps";
import { Hello } from "../src/plugin";

const plugin = new Hello();

test("every tool the manifest names exists and has the prefix", () => {
  expect(problems(plugin.manifest("test-key"), plugin.tools())).toEqual([]);
});

test("the manifest version is package.json's", () => {
  expect(plugin.manifest("test-key").version).toBe(pkg.version);
});

test("a release manifest names the release key, and a test one its own", () => {
  expect(plugin.manifest(plugin.releaseKeyId).publisher.key_id).toBe("gc-2026-01");
  expect(plugin.manifest("hello-test-01").publisher.key_id).toBe("hello-test-01");
});

test("every TSX app is served, and fingerprinted as served", () => {
  for (const app of plugin.manifest(plugin.releaseKeyId).apps ?? []) {
    if (!("entry" in app)) continue;
    const source = plugin.appSource(app.id);
    expect(source, app.id).toBe(APPS[app.id as keyof typeof APPS]);
    expect(app.fingerprint).toBe(fingerprint(source as string));
  }
});
