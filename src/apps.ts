// The TSX app sources this binary serves as buwiz-app://<id>. They are
// imported as text, so `bun build --compile` embeds them: the bytes
// resources/read answers are the bytes the manifest fingerprints, and
// nothing on disk can drift from them.

import home from "../apps/home.tsx" with { type: "text" };

// an import with { type: "text" } is a string at run time; TypeScript types
// it as the module, hence the cast
const text = (source: unknown) => source as string;

export const APPS = {
  home: text(home),
} as const satisfies Record<string, string>;

/** A TSX app's source, as served. */
export const appSource = (id: string): string | undefined => (Object.hasOwn(APPS, id) ? APPS[id as keyof typeof APPS] : undefined);
