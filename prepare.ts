#!/usr/bin/env -S npx tsx
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { styleText } from "node:util";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---- Configuration ----

const OPENSSL_MINIMUM_VERSION = "3.0.0";
const OPENSSL_MAXIMUM_VERSION = "5.0.0";
const OPENSSL_BETA = false;

const PACKAGE_BUILDER_NAME = "AIZAWA Hina";
const PACKAGE_BUILDER_EMAIL = "hina@fetus.jp";
const PACKAGE_VERSION_FORMAT =
  "2.3.0-1.git{H2O_GIT_DATE}.{H2O_GIT_DATE_REBUILD}.{H2O_GIT_REF_SHORT}";

const VERSION_BLOCK_TAG_BEGIN = "# ---- BEGIN VERSION BLOCK ----";
const VERSION_BLOCK_TAG_END = "# ---- END VERSION BLOCK ----";

// ---- Types ----

interface VersionInfo {
  H2O_GIT_DATE: string;
  H2O_GIT_DATE_REBUILD: string;
  H2O_GIT_REF: string;
  H2O_GIT_REF_SHORT: string;
  OPENSSL_VERSION: string;
}

// ---- Main ----

const oldInfo = importMakefile();
const newInfo: VersionInfo = {
  ...getH2OInfo(),
  H2O_GIT_DATE_REBUILD: "",
  OPENSSL_VERSION: getLatestVersionOfOpenSSL(),
};

const changedH2o = oldInfo.H2O_GIT_REF !== newInfo.H2O_GIT_REF;
const changedOpenSSL = oldInfo.OPENSSL_VERSION !== newInfo.OPENSSL_VERSION;
if (!changedH2o && !changedOpenSSL) {
  process.stderr.write(
    styleText("yellow", "Nothing changed.", { stream: process.stderr }) + "\n",
  );
  process.exit(0);
}

if (oldInfo.H2O_GIT_DATE !== newInfo.H2O_GIT_DATE) {
  newInfo.H2O_GIT_DATE_REBUILD = "0";
} else {
  newInfo.H2O_GIT_DATE_REBUILD = String(
    Number(oldInfo.H2O_GIT_DATE_REBUILD) + 1,
  );
}

const mergedPullRequests = changedH2o
  ? getMergedPullRequests(oldInfo.H2O_GIT_REF, newInfo.H2O_GIT_REF)
  : [];

exportMakefile(newInfo);
updateChangelog(newInfo, changedH2o, changedOpenSSL, mergedPullRequests);

process.stdout.write(
  styleText("green", "Ready to build ", { stream: process.stdout }) +
    styleText(["bold", "green"], formatPackageVersion(newInfo), {
      stream: process.stdout,
    }) +
    "\n",
);

// ---- Functions ----

function getH2OInfo(): Pick<
  VersionInfo,
  "H2O_GIT_DATE" | "H2O_GIT_REF" | "H2O_GIT_REF_SHORT"
> {
  process.stderr.write("Getting H2O info...\n");

  const output = execSync("git log -n 1 --date=iso --pretty=tformat:%cd/%H/%h", {
    cwd: join(__dirname, "h2o-repo"),
    encoding: "utf-8",
  }).trim();

  const match = output.match(/^([^/]+)\/([0-9a-f]+)\/([0-9a-f]+)$/);
  if (!match) {
    fatal("Failed to parse H2O info.");
  }

  // Parse the ISO date and format as Ymd in Asia/Tokyo
  const date = new Date(match[1]);
  const formatted = date
    .toLocaleDateString("en-CA", { timeZone: "Asia/Tokyo" }) // en-CA gives YYYY-MM-DD
    .replace(/-/g, "");

  process.stderr.write(`H2O latest commit: ${match[3]} at ${formatted}\n`);

  return {
    H2O_GIT_DATE: formatted,
    H2O_GIT_REF: match[2],
    H2O_GIT_REF_SHORT: match[3],
  };
}

function getMergedPullRequests(oldRef: string, newRef: string): string[] {
  process.stderr.write("Getting merged pull requests...\n");

  let output: string;
  try {
    // %x00 separates records; subject and body are separated by %x01
    output = execSync(
      `git log --first-parent --merges --reverse --format=%s%x01%b%x00 ${oldRef}..${newRef}`,
      { cwd: join(__dirname, "h2o-repo"), encoding: "utf-8" },
    );
  } catch {
    printError("Failed to get merged pull requests.");
    return [];
  }

  const results: string[] = [];
  for (const record of output.split("\0")) {
    const [subject, body = ""] = record.trim().split("\x01");
    if (!subject?.match(/^Merge pull request #\d+ from /)) continue;

    const title = body.trim().split(/\r?\n/)[0]?.trim() || subject;
    results.push(title);
  }

  process.stderr.write(`Found ${results.length} merged pull requests.\n`);

  return results;
}

function getLatestVersionOfOpenSSL(): string {
  process.stderr.write("Getting latest version of OpenSSL...\n");

  const output = execSync(
    "git ls-remote --tags https://github.com/openssl/openssl.git",
    { encoding: "utf-8" },
  );

  const versions: string[] = [];
  for (const line of output.split("\n")) {
    const match = line.match(/\brefs\/tags\/openssl-([\d.]+(?:-beta\d+)?)$/);
    if (!match) continue;

    const version = match[1];
    if (!OPENSSL_BETA && version.includes("-beta")) continue;

    if (
      compareVersions(version, OPENSSL_MINIMUM_VERSION) >= 0 &&
      compareVersions(version, OPENSSL_MAXIMUM_VERSION) < 0
    ) {
      versions.push(version);
    }
  }

  if (versions.length === 0) {
    fatal("No available version of OpenSSL.");
  }

  versions.sort(compareVersions);

  process.stderr.write(`Found ${versions.length} versions of OpenSSL.\n`);

  const latest = versions[versions.length - 1];
  process.stderr.write(`Using OpenSSL version ${latest}.\n`);

  return latest;
}

function importMakefile(): VersionInfo {
  const makefile = readFileSync(join(__dirname, "Makefile"), "utf-8");

  const pos1 = makefile.indexOf(VERSION_BLOCK_TAG_BEGIN);
  const pos2 = makefile.indexOf(VERSION_BLOCK_TAG_END);
  if (pos1 === -1 || pos2 === -1) {
    fatal("Failed to find version block.");
  }

  const block = makefile.slice(
    pos1 + VERSION_BLOCK_TAG_BEGIN.length,
    pos2,
  );

  const results: Record<string, string> = {};
  for (const line of block.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*:=\s*(\S+)\s*$/);
    if (match) {
      results[match[1]] = match[2];
    }
  }

  return results as unknown as VersionInfo;
}

function exportMakefile(info: VersionInfo): void {
  const entries = Object.entries(info).sort(([a], [b]) => a.localeCompare(b));

  const oldMakefile = readFileSync(join(__dirname, "Makefile"), "utf-8");

  const pos1 = oldMakefile.indexOf(VERSION_BLOCK_TAG_BEGIN);
  const pos2 = oldMakefile.indexOf(VERSION_BLOCK_TAG_END);
  if (pos1 === -1 || pos2 === -1) {
    fatal("Failed to find version block.");
  }

  const newMakefile =
    oldMakefile.slice(0, pos1) +
    VERSION_BLOCK_TAG_BEGIN +
    "\n" +
    entries.map(([key, value]) => `${key} := ${value}`).join("\n") +
    "\n" +
    VERSION_BLOCK_TAG_END +
    oldMakefile.slice(pos2 + VERSION_BLOCK_TAG_END.length);

  writeFileSync(join(__dirname, "Makefile"), newMakefile);
  process.stderr.write("Makefile updated.\n");
}

function updateChangelog(
  newInfo: VersionInfo,
  changedH2o: boolean,
  changedOpenSSL: boolean,
  mergedPullRequests: string[],
): void {
  const now = new Date();
  // RPM changelog date format: "Day Mon DD YYYY" e.g. "Wed Apr 08 2026"
  const dateStr = now.toLocaleDateString("en-US", {
    timeZone: "Asia/Tokyo",
    weekday: "short",
    month: "short",
    day: "2-digit",
    year: "numeric",
  });
  // toLocaleDateString gives "Wed, Apr 08, 2026" — remove commas
  const rpmDate = dateStr.replace(/,/g, "");

  const version = formatPackageVersion(newInfo);

  const lines: string[] = [
    `* ${rpmDate} ${PACKAGE_BUILDER_NAME} <${PACKAGE_BUILDER_EMAIL}> - ${version}`,
  ];

  if (changedH2o) {
    lines.push(`- Update H2O to revision ${newInfo.H2O_GIT_REF}`);
    for (const pr of mergedPullRequests) {
      // "%" must be escaped in RPM spec files to avoid macro expansion
      lines.push(`  - ${pr.replace(/%/g, "%%")}`);
    }
  }
  if (changedOpenSSL) {
    lines.push(`- Build with OpenSSL ${newInfo.OPENSSL_VERSION}`);
  }
  if (!changedH2o && !changedOpenSSL) {
    lines.push("- Rebuild");
  }

  const changelogPath = join(__dirname, "rpmbuild/SPECS/changelog");
  const oldChangelog = readFileSync(changelogPath, "utf-8").trim();

  writeFileSync(changelogPath, lines.join("\n") + "\n\n" + oldChangelog + "\n");
}

// ---- Utilities ----

function printError(message: string): void {
  process.stderr.write(
    styleText("red", message, { stream: process.stderr }) + "\n",
  );
}

function fatal(message: string): never {
  printError(message);
  process.exit(1);
}

function formatPackageVersion(info: VersionInfo): string {
  return PACKAGE_VERSION_FORMAT.replace(
    /\{([A-Z0-9_]+)\}/g,
    (original, key: string) =>
      (info as unknown as Record<string, string>)[key] ?? original,
  );
}

/**
 * Compare two version strings (e.g. "3.1.2" vs "3.2.0").
 * Returns negative if a < b, 0 if equal, positive if a > b.
 * Handles beta suffixes: "3.1.0-beta1" < "3.1.0".
 */
function compareVersions(a: string, b: string): number {
  const parseBeta = (v: string) => {
    const match = v.match(/^([\d.]+?)(?:-beta(\d+))?$/);
    return match
      ? { base: match[1], beta: match[2] ? Number(match[2]) : Infinity }
      : { base: v, beta: Infinity };
  };

  const pa = parseBeta(a);
  const pb = parseBeta(b);

  const partsA = pa.base.split(".").map(Number);
  const partsB = pb.base.split(".").map(Number);

  const len = Math.max(partsA.length, partsB.length);
  for (let i = 0; i < len; i++) {
    const diff = (partsA[i] ?? 0) - (partsB[i] ?? 0);
    if (diff !== 0) return diff;
  }

  return pa.beta - pb.beta;
}
