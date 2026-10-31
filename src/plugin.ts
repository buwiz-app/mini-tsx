// Hello, the mini-tsx template's mini app (app.buwiz.hello).
//
// The SDK (@buwiz/sdk/plugin) serves MCP, answers the reserved buwiz.*
// tools and checks every caller; this file ties together what is Hello's:
// the manifest (manifest.ts), the app sources (apps.ts) and the tools
// (tools.ts).

import { type Args, type Plugin, Tickets } from "@buwiz/sdk/plugin";
import pkg from "../package.json";
import { appSource } from "./apps";
import { ID, RELEASE_KEY_ID, unsigned } from "./manifest";
import * as tools from "./tools";

export class Hello implements Plugin {
  readonly id = ID;
  readonly name = pkg.name;
  readonly version = pkg.version;
  readonly releaseKeyId = RELEASE_KEY_ID;
  readonly instructions =
    "Hello greets the user's friends. Use hello_greet with a friend's ticket from an @hello:friend token, or without one to greet everyone.";

  /** The mini app's state: its subjects' tickets. A real mini app opens its
   *  own store here too. */
  readonly tickets = new Tickets<string>();

  manifest = unsigned;
  appSource = appSource;
  tools = tools.list;

  call(tool: string, args: Args) {
    return tools.call(this.tickets, tool, args);
  }

  ticketTitle(ticket: string) {
    // a friend's name is the title the user sees; a real subject's title
    // must not reveal what the ticket hides
    return this.tickets.subject(ticket);
  }

  uninstall() {
    this.tickets.clear();
  }
}
