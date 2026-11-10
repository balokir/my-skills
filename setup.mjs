import {
  existsSync, lstatSync, mkdirSync, readdirSync, realpathSync, symlinkSync,
  unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const checkoutRoot = dirname(fileURLToPath(import.meta.url));
const skillsHome = join(homedir(), ".agents", "skills");
const links = readdirSync(checkoutRoot, { withFileTypes: true })
  .filter((entry) => (
    entry.isDirectory()
    && existsSync(join(checkoutRoot, entry.name, "SKILL.md"))
  ))
  .sort((left, right) => left.name.localeCompare(right.name))
  .map((entry) => ({
    name: entry.name,
    target: join(checkoutRoot, entry.name),
    dest: join(skillsHome, entry.name),
  }));

function state(link) {
  let stat;
  try {
    stat = lstatSync(link.dest);
  } catch (error) {
    if (error?.code === "ENOENT") return "missing";
    throw error;
  }
  if (!stat.isSymbolicLink()) return "conflict";
  try {
    // Works for Windows directory symlinks, including NT path prefixes.
    const actual = realpathSync(link.dest);
    const expected = realpathSync(link.target);
    const normalize = (path) => process.platform === "win32"
      ? path.toLowerCase() : path;
    return normalize(actual) === normalize(expected) ? "linked" : "conflict";
  } catch {
    return "conflict"; // Never remove a dangling or unresolvable link.
  }
}

function checkOwnership() {
  for (const link of links) {
    if (state(link) === "conflict") {
      throw new Error("Refusing unexpected path: " + link.dest);
    }
  }
}

function install() {
  checkOwnership();
  mkdirSync(skillsHome, { recursive: true });
  const created = [];
  try {
    for (const link of links) {
      if (state(link) === "linked") continue;
      symlinkSync(link.target, link.dest, "dir");
      created.push(link);
      if (state(link) !== "linked") {
        throw new Error("Link verification failed: " + link.dest);
      }
    }
  } catch (error) {
    // Never remove existing user state, even if a partially created link fails.
    for (const link of created.reverse()) {
      if (state(link) === "linked") unlinkSync(link.dest);
    }
    throw error;
  }
  console.log("Installed personal skills from: " + checkoutRoot);
  console.log("Skills directory: " + skillsHome);
  console.log("Start a fresh Codex session if the skills are not detected yet.");
}

function uninstall() {
  checkOwnership();
  for (const link of links) {
    if (state(link) === "linked") unlinkSync(link.dest);
  }
  console.log("Owned skill links removed; unrelated skills retained.");
}

function status() {
  for (const link of links) console.log(link.name + ": " + state(link));
}

const action = process.argv[2] ?? "status";
try {
  if (action === "install") install();
  else if (action === "uninstall") uninstall();
  else if (action === "status") status();
  else throw new Error("Usage: node setup.mjs install|status|uninstall");
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
