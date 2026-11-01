// hello-mini-app mcp | manifest [--key-id <id>] | app-source <id> | package …: the SDK's
// command line (--help says more).

import { main } from "@buwiz/sdk/plugin";
import { Hello } from "./plugin";

process.exit(await main(new Hello()));
