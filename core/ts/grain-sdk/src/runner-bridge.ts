import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

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
const packageRoot = findPackageRoot(moduleDir);
const runnerDistRoot = resolve(packageRoot, "../../../runner/typescript/dist/src");

const [
  opsModule,
  expectModule,
  cborModule,
  utilsModule
] = await Promise.all([
  import(pathToFileURL(resolve(runnerDistRoot, "ops.js")).href) as Promise<typeof import("../../../../runner/typescript/dist/src/ops.js")>,
  import(pathToFileURL(resolve(runnerDistRoot, "expect.js")).href) as Promise<typeof import("../../../../runner/typescript/dist/src/expect.js")>,
  import(pathToFileURL(resolve(runnerDistRoot, "cbor.js")).href) as Promise<typeof import("../../../../runner/typescript/dist/src/cbor.js")>,
  import(pathToFileURL(resolve(runnerDistRoot, "utils.js")).href) as Promise<typeof import("../../../../runner/typescript/dist/src/utils.js")>
]);

export const { executeOperation } = opsModule;
export const { evaluateVector } = expectModule;
export const { encodeCanonical } = cborModule;
export const { compareCanonicalMapKey } = utilsModule;
