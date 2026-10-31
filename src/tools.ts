// Hello's tools: hello_greet, and hello_resolve for the /hello command and
// the @hello:friend scope.
//
// The SDK has already checked the caller against the manifest (an app's
// grant, read-only resolves and routines). What is left is Hello's own
// rule: a ticket Hello did not issue is refused, not guessed at (P1).

import { type Args, type Json, type Result, type Tickets, type Tool, fail, ok } from "@buwiz/sdk/plugin";
import { TITLE } from "./manifest";

export const GREET = "hello_greet";
export const RESOLVE = "hello_resolve";

/** The subjects Hello knows. A real mini app looks them up in its store;
 *  tickets stand for them everywhere outside this process. */
const FRIENDS = ["Ada", "Grace", "Linus"];

/** Every tool, in tools/list order. */
export const list = (): Tool[] => [
  {
    name: GREET,
    description: "Greet a friend by ticket, or everyone.",
    inputSchema: { type: "object", properties: { ticket: { type: "string", description: "A friend's ticket (tkt_…)" } } },
    readOnly: true,
  },
  { name: RESOLVE, description: "Resolve /hello and @hello:friend tokens.", inputSchema: { type: "object" }, readOnly: true },
];

/** Run one of list(). */
export function call(tickets: Tickets<string>, tool: string, args: Args): Result {
  if (tool === GREET) return greet(tickets, args);
  if (tool === RESOLVE) return resolve(tickets, args);
  return fail("not_found", "No such tool.");
}

function greet(tickets: Tickets<string>, args: Args): Result {
  if (args.ticket === undefined) return ok({ greeting: "Hi, world" });
  const name = tickets.subject(args.ticket);
  return name === undefined ? fail("not_found", "That friend is no longer available.") : ok({ greeting: `Hi, ${name}` });
}

/** {kind, name, value, complete} in; one of choices, open, token, prompt or
 *  error out. */
function resolve(tickets: Tickets<string>, args: Args): Result {
  const value = String(args.value ?? "").trim();
  const matches = FRIENDS.filter((f) => f.toLowerCase().startsWith(value.toLowerCase()));

  if (args.kind === "command") {
    const [one] = matches;
    const props: Record<string, Json> = matches.length === 1 && value && one ? { ticket: tickets.issue(one) } : {};
    return ok({ result: "open", app: "home", props, title: TITLE, placement: "full" });
  }

  if (args.complete === true) {
    return ok({ result: "choices", choices: matches.slice(0, 20).map((f) => ({ label: f, detail: "A friend", value: tickets.issue(f) })) });
  }

  // a value is a ticket already (a chosen completion) or typed text
  const subject = tickets.subject(value) ?? FRIENDS.find((f) => f.toLowerCase() === value.toLowerCase());
  if (subject === undefined) return ok({ result: "error", message: `No friend called ${value.slice(0, 60)}.` });
  return ok({ result: "token", ticket: tickets.issue(subject), title: subject });
}
