// The screen gate catches detached setters without flagging wrapped callbacks.
// Fixtures are isolated so the checks cover both matching and path handling.

import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { expect, test } from "bun:test";

const root = resolve(import.meta.dir, "..");
const script = join(root, "tools/no-detached-setters.sh");

async function withTempDir(run: (dir: string) => Promise<void>) {
  const dir = await mkdtemp(join(tmpdir(), "no-detached-setters-"));
  try {
    await run(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

function runGate(...paths: string[]) {
  const result = Bun.spawnSync(["bash", script, ...paths], {
    cwd: root,
    stdout: "pipe",
    stderr: "pipe",
  });
  return {
    exitCode: result.exitCode,
    output: `${new TextDecoder().decode(result.stdout)}${new TextDecoder().decode(result.stderr)}`,
  };
}

test("catches a detached setter", async () => {
  await withTempDir(async (dir) => {
    await writeFile(join(dir, "bad.tsx"), ["const Screen = () => (", "  <Input value={x()} onChange={x.set} />", ");", ""].join("\n"));
    const result = runGate(dir);
    expect(result.exitCode).toBe(1);
    expect(result.output).toContain("bad.tsx:2:");
    expect(result.output).toContain("onChange={x.set}");
  });
});

test("catches multi-character, dotted and dollar-prefixed setters", async () => {
  await withTempDir(async (dir) => {
    await writeFile(join(dir, "bad.tsx"), ["<Input onChange={name.set} />", "<Input onValue={form.name.set} />", "<Input onChange={$v.set} />", ""].join("\n"));
    const result = runGate(dir);
    expect(result.exitCode).toBe(1);
    expect(result.output).toContain("bad.tsx:1:");
    expect(result.output).toContain("bad.tsx:2:");
    expect(result.output).toContain("bad.tsx:3:");
  });
});

test("allows wrapped setters and ordinary setter calls", async () => {
  await withTempDir(async (dir) => {
    await writeFile(join(dir, "good.tsx"), ["<Input onChange={(v) => x.set(v)} />", "greeting.set(String(r.greeting))", ""].join("\n"));
    const result = runGate(dir);
    expect(result.exitCode).toBe(0);
    expect(result.output).toBe("");
  });
});

test("ignores non-TSX files", async () => {
  await withTempDir(async (dir) => {
    await writeFile(join(dir, "notes.md"), "onChange={x.set}\n");
    const result = runGate(dir);
    expect(result.exitCode).toBe(0);
    expect(result.output).toBe("");
  });
});

test("fails when a requested path is missing", async () => {
  await withTempDir(async (dir) => {
    const result = runGate(join(dir, "nope"));
    expect(result.exitCode).toBe(2);
    expect(result.output).not.toBe("");
  });
});

test("the template screens have no detached setters", () => {
  const result = runGate();
  expect(result.exitCode).toBe(0);
  expect(result.output).toBe("");
});
