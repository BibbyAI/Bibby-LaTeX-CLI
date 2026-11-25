#!/usr/bin/env node
/**
 * npx wrapper. Hands off to the shell installer on macOS/Linux/WSL and to
 * PowerShell on Windows, with stdio inherited so the prompts still work.
 */
"use strict";

const { spawn, spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");

const root = path.resolve(__dirname, "..");
const args = process.argv.slice(2);

function fail(msg) {
  process.stderr.write(`bibby-latex: ${msg}\n`);
  process.exit(1);
}

let cmd;
let cmdArgs;

if (process.platform === "win32") {
  const ps1 = path.join(root, "windows", "install.ps1");
  if (!fs.existsSync(ps1)) fail("windows/install.ps1 is missing from this package");

  const pwsh =
    ["pwsh", "powershell"].find(
      (exe) => spawnSync(exe, ["-NoProfile", "-Command", "exit 0"], { stdio: "ignore" }).status === 0
    ) || "powershell";
  cmd = pwsh;
  cmdArgs = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1, ...args];
} else {
  const sh = path.join(root, "src", "bibby-latex.sh");
  if (!fs.existsSync(sh)) fail("src/bibby-latex.sh is missing from this package");
  try {
    fs.chmodSync(sh, 0o755);
  } catch {
    /* read-only install dir is fine, bash runs it anyway */
  }
  cmd = "bash";
  cmdArgs = [sh, ...args];
}

const child = spawn(cmd, cmdArgs, { stdio: "inherit", env: process.env });

child.on("error", (err) => {
  if (err.code === "ENOENT") fail(`${cmd} not found on PATH`);
  fail(err.message);
});

child.on("exit", (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exit(code === null ? 1 : code);
});
