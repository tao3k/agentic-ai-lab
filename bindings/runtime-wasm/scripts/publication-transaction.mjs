// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import { randomUUID } from "node:crypto";
import * as nodeFs from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";

const journalSchema = "agentic-ai-lab.runtime-wasm-publication.v1";
const rollbackStates = new Set([
  "prepared",
  "member-1-published",
  "pair-published",
]);
const terminalStates = new Set(["committed", "rolled-back"]);

function aggregate(message, errors) {
  return new AggregateError(errors, message);
}

function syncFile(path, filesystem) {
  const file = filesystem.openSync(path, "r");
  try {
    filesystem.fsyncSync(file);
  } finally {
    filesystem.closeSync(file);
  }
}

function syncDirectory(path, filesystem) {
  const directory = filesystem.openSync(path, "r");
  try {
    filesystem.fsyncSync(directory);
  } finally {
    filesystem.closeSync(directory);
  }
}

function writeJournal(journalPath, journal, filesystem) {
  const temporary = `${journalPath}.${process.pid}-${randomUUID()}.tmp`;
  let file = null;
  try {
    file = filesystem.openSync(temporary, "wx", 0o600);
    filesystem.writeFileSync(file, `${JSON.stringify(journal)}\n`, "utf8");
    filesystem.fsyncSync(file);
    filesystem.closeSync(file);
    file = null;
    filesystem.renameSync(temporary, journalPath);
    syncDirectory(dirname(journalPath), filesystem);
  } finally {
    if (file !== null) filesystem.closeSync(file);
    filesystem.rmSync(temporary, { force: true });
  }
}

function assertRegularFileIfPresent(path, filesystem) {
  let status;
  try {
    status = filesystem.lstatSync(path);
  } catch (error) {
    if (error?.code === "ENOENT") return;
    throw error;
  }
  if (status.isSymbolicLink() || !status.isFile()) {
    throw new Error(
      `Workflow publication path must be a regular file: ${path}`,
    );
  }
}

function validateJournal(journalPath, journal, filesystem) {
  if (
    journal?.schema !== journalSchema ||
    typeof journal.generation !== "string" ||
    !Array.isArray(journal.entries) ||
    journal.entries.length !== 2
  ) {
    throw new Error(`Invalid workflow publication journal: ${journalPath}`);
  }
  const validState =
    journal.state === "preparing" ||
    rollbackStates.has(journal.state) ||
    terminalStates.has(journal.state);
  if (!validState) {
    throw new Error(
      `Unknown workflow publication journal state: ${journal.state}`,
    );
  }
  const publicationDirectory = dirname(journalPath);
  const stagedPaths = new Set();
  const destinationPaths = new Set();
  const backupPaths = new Set();
  for (const entry of journal.entries) {
    if (
      typeof entry?.staged !== "string" ||
      typeof entry.destination !== "string" ||
      typeof entry.backup !== "string" ||
      typeof entry.previousExists !== "boolean" ||
      !isAbsolute(entry.staged) ||
      !isAbsolute(entry.destination) ||
      !isAbsolute(entry.backup) ||
      resolve(entry.staged) !== entry.staged ||
      resolve(entry.destination) !== entry.destination ||
      resolve(entry.backup) !== entry.backup ||
      dirname(entry.staged) !== publicationDirectory ||
      dirname(entry.destination) !== publicationDirectory ||
      dirname(entry.backup) !== publicationDirectory ||
      entry.backup !==
        `${entry.destination}.${journal.generation}.backup`
    ) {
      throw new Error(
        `Unsafe workflow publication journal entry: ${journalPath}`,
      );
    }
    stagedPaths.add(entry.staged);
    destinationPaths.add(entry.destination);
    backupPaths.add(entry.backup);
  }
  const allPaths = new Set([
    ...stagedPaths,
    ...destinationPaths,
    ...backupPaths,
    journalPath,
  ]);
  if (
    stagedPaths.size !== 2 ||
    destinationPaths.size !== 2 ||
    backupPaths.size !== 2 ||
    allPaths.size !== 7
  ) {
    throw new Error(
      `Aliased workflow publication journal paths: ${journalPath}`,
    );
  }
  assertRegularFileIfPresent(journalPath, filesystem);
  for (const path of allPaths) {
    assertRegularFileIfPresent(path, filesystem);
  }
  return journal;
}

function readJournal(journalPath, filesystem) {
  assertRegularFileIfPresent(journalPath, filesystem);
  return validateJournal(
    journalPath,
    JSON.parse(filesystem.readFileSync(journalPath, "utf8")),
    filesystem,
  );
}

function cleanupTerminalJournal(journalPath, journal, filesystem) {
  const errors = [];
  for (const entry of journal.entries) {
    try {
      filesystem.rmSync(entry.backup, { force: true });
    } catch (error) {
      errors.push(error);
    }
  }
  if (errors.length > 0) {
    throw aggregate(
      `Unable to clean workflow publication backups for ${journalPath}`,
      errors,
    );
  }
  filesystem.rmSync(journalPath);
  syncDirectory(dirname(journalPath), filesystem);
}

function restorePreviousPair(journalPath, journal, filesystem) {
  const errors = [];
  const publicationDirectories = new Set();
  for (const entry of journal.entries) {
    publicationDirectories.add(dirname(entry.destination));
    try {
      if (entry.previousExists) {
        if (!filesystem.existsSync(entry.backup)) {
          throw new Error(
            `Missing workflow publication backup: ${entry.backup}`,
          );
        }
        filesystem.copyFileSync(entry.backup, entry.destination);
        syncFile(entry.destination, filesystem);
      } else {
        filesystem.rmSync(entry.destination, { force: true });
      }
    } catch (error) {
      errors.push(error);
    }
  }
  for (const publicationDirectory of publicationDirectories) {
    try {
      syncDirectory(publicationDirectory, filesystem);
    } catch (error) {
      errors.push(error);
    }
  }
  if (errors.length > 0) {
    throw aggregate(
      `Unable to restore the previous workflow publication pair for ${journalPath}`,
      errors,
    );
  }
  const rolledBack = { ...journal, state: "rolled-back" };
  writeJournal(journalPath, rolledBack, filesystem);
  cleanupTerminalJournal(journalPath, rolledBack, filesystem);
}

export function recoverPublication(
  journalPath,
  { filesystem = nodeFs } = {},
) {
  if (!filesystem.existsSync(journalPath)) return false;
  const journal = readJournal(journalPath, filesystem);
  if (terminalStates.has(journal.state)) {
    cleanupTerminalJournal(journalPath, journal, filesystem);
    return true;
  }
  if (journal.state === "preparing") {
    const rolledBack = { ...journal, state: "rolled-back" };
    writeJournal(journalPath, rolledBack, filesystem);
    cleanupTerminalJournal(journalPath, rolledBack, filesystem);
    return true;
  }
  restorePreviousPair(journalPath, journal, filesystem);
  return true;
}

export function stagePublicationFile(
  source,
  staged,
  { filesystem = nodeFs } = {},
) {
  filesystem.mkdirSync(dirname(staged), { recursive: true });
  filesystem.copyFileSync(source, staged);
  filesystem.chmodSync(staged, 0o644);
  syncFile(staged, filesystem);
  syncDirectory(dirname(staged), filesystem);
}

export function publishFilePair(
  entries,
  journalPath,
  { filesystem = nodeFs } = {},
) {
  if (!isAbsolute(journalPath) || entries.length !== 2) {
    throw new Error("Workflow publication requires an absolute two-file journal");
  }
  const publicationDirectory = dirname(journalPath);
  const stagedPaths = new Set();
  const destinationPaths = new Set();
  for (const entry of entries) {
    if (
      !isAbsolute(entry.staged) ||
      !isAbsolute(entry.destination) ||
      resolve(entry.staged) !== entry.staged ||
      resolve(entry.destination) !== entry.destination ||
      dirname(entry.staged) !== publicationDirectory ||
      dirname(entry.destination) !== publicationDirectory
    ) {
      throw new Error(
        "Workflow publication stages, destinations, and journal must share one directory",
      );
    }
    if (!filesystem.existsSync(entry.staged)) {
      throw new Error(`Missing staged workflow publication: ${entry.staged}`);
    }
    assertRegularFileIfPresent(entry.staged, filesystem);
    assertRegularFileIfPresent(entry.destination, filesystem);
    stagedPaths.add(entry.staged);
    destinationPaths.add(entry.destination);
  }
  const transactionPaths = new Set([
    ...stagedPaths,
    ...destinationPaths,
    journalPath,
  ]);
  if (
    stagedPaths.size !== 2 ||
    destinationPaths.size !== 2 ||
    transactionPaths.size !== 5
  ) {
    throw new Error("Workflow publication paths must be distinct");
  }

  recoverPublication(journalPath, { filesystem });
  const previousExists = entries.map((entry) =>
    filesystem.existsSync(entry.destination),
  );
  if (previousExists[0] !== previousExists[1]) {
    throw new Error(
      "Existing workflow publication is incomplete; refusing to replace a mixed pair",
    );
  }

  const generation = randomUUID();
  let journal = {
    schema: journalSchema,
    generation,
    state: "preparing",
    entries: entries.map((entry, index) => ({
      staged: entry.staged,
      destination: entry.destination,
      backup: `${entry.destination}.${generation}.backup`,
      previousExists: previousExists[index],
    })),
  };
  writeJournal(journalPath, journal, filesystem);

  try {
    for (const entry of journal.entries) {
      if (entry.previousExists) {
        filesystem.copyFileSync(entry.destination, entry.backup);
        syncFile(entry.backup, filesystem);
      }
    }
    syncDirectory(publicationDirectory, filesystem);
    journal = { ...journal, state: "prepared" };
    writeJournal(journalPath, journal, filesystem);

    for (let index = 0; index < journal.entries.length; index += 1) {
      const entry = journal.entries[index];
      filesystem.renameSync(entry.staged, entry.destination);
      syncDirectory(publicationDirectory, filesystem);
      journal = {
        ...journal,
        state: index === 0 ? "member-1-published" : "pair-published",
      };
      writeJournal(journalPath, journal, filesystem);
    }
    journal = { ...journal, state: "committed" };
    writeJournal(journalPath, journal, filesystem);
  } catch (publicationError) {
    try {
      recoverPublication(journalPath, { filesystem });
    } catch (recoveryError) {
      throw aggregate(
        "Workflow publication failed and recovery is incomplete",
        [publicationError, recoveryError],
      );
    }
    throw publicationError;
  }

  cleanupTerminalJournal(journalPath, journal, filesystem);
  return { schema: journalSchema, generation, state: "committed" };
}
