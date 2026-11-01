// Runs `cf d1 <command> <database ID> [options]` for the DB binding, as cf takes the database only by ID.
// Local commands use the state of the Vite dev server unless `--persist-to` is given,
// and migrations use db/migrations.
//
//   node db/d1.ts migrations apply --local
//   node db/d1.ts raw --local --sql @db/seed.sql
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { databaseId } from "../cloudflare.config.ts";

const args = process.argv.slice(2);
const commandLength = args.findIndex((arg) => arg.startsWith("-"));
const command = commandLength === -1 ? args : args.slice(0, commandLength);
const options = commandLength === -1 ? [] : args.slice(commandLength);

const defaults = [
  ...(command[0] === "migrations" ? ["--dir", "db/migrations"] : []),
  ...(options.includes("--local") && !options.includes("--persist-to") ? ["--persist-to", ".cloudflare/state"] : []),
];

const cf = fileURLToPath(new URL("bin/cf", import.meta.resolve("cf/package.json")));
const result = spawnSync(process.execPath, [cf, "d1", ...command, databaseId, ...options, ...defaults], { stdio: "inherit" });
process.exit(result.status ?? 1);
