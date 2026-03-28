import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

function findPackageRoot(start: string): string {
  let current = start;
  while (true) {
    if (existsSync(resolve(current, "package.json"))) {
      return current;
    }
    const parent = dirname(current);
    if (parent === current) {
      throw new Error(`unable to locate package.json from ${start}`);
    }
    current = parent;
  }
}

const moduleDir = fileURLToPath(new URL(".", import.meta.url));

export const packageRoot = findPackageRoot(moduleDir);
export const repoRoot = resolve(packageRoot, "../../..");

export function repoPath(...segments: string[]): string {
  return resolve(repoRoot, ...segments);
}
