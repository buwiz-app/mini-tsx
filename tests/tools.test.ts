// Hello's tools through the SDK's harness: a provisioned server, and calls
// as the model, a resolve and the home screen, the way the Bot makes them.

import { expect, test } from "bun:test";
import { Harness, isTicket } from "@buwiz/sdk/plugin";
import { Hello } from "../src/plugin";

test("greets everyone without a ticket", async () => {
  const h = await Harness.start(new Hello());
  expect(await h.agent("hello_greet")).toEqual({ greeting: "Hi, world" });
});

test("a friend resolves to a ticket that greets them", async () => {
  const h = await Harness.start(new Hello());
  const token = (await h.resolve("hello_resolve", { kind: "scope", name: "friend", value: "ada" })) as Record<string, string>;
  expect(token).toMatchObject({ result: "token", title: "Ada" });
  expect(isTicket(token.ticket)).toBe(true);
  // the home screen calls hello_greet; its open grants it
  expect(await h.app("home", "hello_greet", { ticket: token.ticket as string })).toEqual({ greeting: "Hi, Ada" });
});

test("a ticket Hello did not issue is refused", async () => {
  const h = await Harness.start(new Hello());
  await expect(h.agent("hello_greet", { ticket: "tkt_0000000000000000000000000A" })).rejects.toMatchObject({ code: "not_found" });
});

test("completion offers choices as tickets", async () => {
  const h = await Harness.start(new Hello());
  const { choices } = (await h.resolve("hello_resolve", { kind: "scope", name: "friend", value: "", complete: true })) as {
    choices: { label: string; value: string }[];
  };
  expect(choices.map((c) => c.label)).toEqual(["Ada", "Grace", "Linus"]);
  expect(choices.every((c) => isTicket(c.value))).toBe(true);
});

test("the command opens home for one friend or none", async () => {
  const h = await Harness.start(new Hello());
  const open = (await h.resolve("hello_resolve", { kind: "command", name: "hello", value: "grace" })) as {
    result: string;
    app: string;
    props: { ticket?: string };
  };
  expect(open).toMatchObject({ result: "open", app: "home" });
  expect(isTicket(open.props.ticket)).toBe(true);
  expect(await h.resolve("hello_resolve", { kind: "command", name: "hello", value: "" })).toMatchObject({ props: {} });
});

test("uninstall forgets every ticket", async () => {
  const h = await Harness.start(new Hello());
  const { ticket } = (await h.resolve("hello_resolve", { kind: "scope", value: "Linus" })) as { ticket: string };
  await h.call("buwiz.uninstall", {}, null);
  expect(await h.call("buwiz.ticket.resolve", { ticket }, null)).toEqual({ valid: false });
});
