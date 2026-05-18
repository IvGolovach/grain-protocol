import { createBrokerServer } from "./server.js";

const port = parsePort(process.env.PORT) ?? 8787;
const host = process.env.HOST ?? "127.0.0.1";
const server = createBrokerServer();

server.listen(port, host, () => {
  process.stdout.write(`grain-food-analysis-broker listening on http://${host}:${port}\n`);
});

function parsePort(value: string | undefined): number | undefined {
  if (value === undefined) return undefined;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    throw new Error("PORT must be an integer from 1 to 65535");
  }
  return parsed;
}
