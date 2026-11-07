// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import * as nodeFs from "node:fs";
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  publishFilePair,
  recoverPublication,
} from "../scripts/publication-transaction.mjs";

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "agentic-ai-lab-publication-"));
  const descriptor = join(root, "human-capability.descriptor.bin");
  const arena = join(root, "human-capability.arena.bin");
  const paths = {
    root,
    journal: join(root, ".human-capability.publication.json"),
    descriptor,
    arena,
    stagedDescriptor: join(root, ".descriptor.tmp"),
    stagedArena: join(root, ".arena.tmp"),
    backupDescriptor: `${descriptor}.test-generation.backup`,
    backupArena: `${arena}.test-generation.backup`,
  };
  writeFileSync(paths.descriptor, "old-descriptor");
  writeFileSync(paths.arena, "old-arena");
  writeFileSync(paths.stagedDescriptor, "new-descriptor");
  writeFileSync(paths.stagedArena, "new-arena");
  return paths;
}

function entries(paths) {
  return [
    {
      staged: paths.stagedDescriptor,
      destination: paths.descriptor,
    },
    {
      staged: paths.stagedArena,
      destination: paths.arena,
    },
  ];
}

function journal(paths, state) {
  return {
    schema: "agentic-ai-lab.runtime-wasm-publication.v1",
    generation: "test-generation",
    state,
    entries: [
      {
        staged: paths.stagedDescriptor,
        destination: paths.descriptor,
        backup: paths.backupDescriptor,
        previousExists: true,
      },
      {
        staged: paths.stagedArena,
        destination: paths.arena,
        backup: paths.backupArena,
        previousExists: true,
      },
    ],
  };
}

function assertPair(paths, descriptor, arena) {
  assert.equal(readFileSync(paths.descriptor, "utf8"), descriptor);
  assert.equal(readFileSync(paths.arena, "utf8"), arena);
}

{
  const paths = fixture();
  try {
    publishFilePair(entries(paths), paths.journal);
    assertPair(paths, "new-descriptor", "new-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    const malformed = journal(paths, "committed");
    malformed.entries[0].backup = paths.descriptor;
    writeFileSync(paths.journal, `${JSON.stringify(malformed)}\n`);
    assert.throws(
      () => recoverPublication(paths.journal),
      /Unsafe workflow publication journal entry/,
    );
    assertPair(paths, "old-descriptor", "old-arena");
    assert.equal(nodeFs.existsSync(paths.journal), true);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    const aliased = entries(paths);
    aliased[1].destination = paths.descriptor;
    assert.throws(
      () => publishFilePair(aliased, paths.journal),
      /paths must be distinct/,
    );
    assertPair(paths, "old-descriptor", "old-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    rmSync(paths.descriptor);
    symlinkSync(paths.arena, paths.descriptor);
    assert.throws(
      () => publishFilePair(entries(paths), paths.journal),
      /must be a regular file/,
    );
    assert.equal(readFileSync(paths.arena, "utf8"), "old-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

for (const failedStage of ["stagedDescriptor", "stagedArena"]) {
  const paths = fixture();
  const failedDestination =
    failedStage === "stagedDescriptor" ? paths.descriptor : paths.arena;
  const filesystem = {
    ...nodeFs,
    renameSync(source, destination) {
      if (
        source === paths[failedStage] &&
        destination === failedDestination
      ) {
        throw new Error(`injected ${failedStage} publication rename failure`);
      }
      nodeFs.renameSync(source, destination);
    },
  };
  try {
    assert.throws(
      () =>
        publishFilePair(entries(paths), paths.journal, {
          filesystem,
        }),
      /injected staged(?:Descriptor|Arena) publication rename failure/,
    );
    assertPair(paths, "old-descriptor", "old-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

for (const state of ["member-1-published", "pair-published"]) {
  const paths = fixture();
  try {
    writeFileSync(paths.backupDescriptor, "old-descriptor");
    writeFileSync(paths.backupArena, "old-arena");
    writeFileSync(paths.descriptor, "new-descriptor");
    if (state === "pair-published") {
      writeFileSync(paths.arena, "new-arena");
    }
    writeFileSync(paths.journal, `${JSON.stringify(journal(paths, state))}\n`);
    recoverPublication(paths.journal);
    assertPair(paths, "old-descriptor", "old-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
    assert.equal(nodeFs.existsSync(paths.backupDescriptor), false);
    assert.equal(nodeFs.existsSync(paths.backupArena), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    writeFileSync(paths.backupDescriptor, "old-descriptor");
    writeFileSync(paths.backupArena, "old-arena");
    writeFileSync(paths.descriptor, "new-descriptor");
    writeFileSync(paths.arena, "new-arena");
    writeFileSync(
      paths.journal,
      `${JSON.stringify(journal(paths, "committed"))}\n`,
    );
    recoverPublication(paths.journal);
    assertPair(paths, "new-descriptor", "new-arena");
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  const restoreAttempts = [];
  try {
    writeFileSync(paths.backupDescriptor, "old-descriptor");
    writeFileSync(paths.backupArena, "old-arena");
    writeFileSync(paths.descriptor, "new-descriptor");
    writeFileSync(paths.journal, `${JSON.stringify(journal(paths, "member-1-published"))}\n`);
    const filesystem = {
      ...nodeFs,
      copyFileSync(source, destination) {
        if (
          source === paths.backupDescriptor ||
          source === paths.backupArena
        ) {
          restoreAttempts.push(source);
        }
        if (source === paths.backupDescriptor) {
          throw new Error("injected descriptor restore failure");
        }
        nodeFs.copyFileSync(source, destination);
      },
    };
    assert.throws(
      () => recoverPublication(paths.journal, { filesystem }),
      AggregateError,
    );
    assert.deepEqual(restoreAttempts, [
      paths.backupDescriptor,
      paths.backupArena,
    ]);
    assert.equal(nodeFs.existsSync(paths.journal), true);
    assert.equal(nodeFs.existsSync(paths.backupDescriptor), true);
    assert.equal(nodeFs.existsSync(paths.backupArena), true);
    recoverPublication(paths.journal);
    assertPair(paths, "old-descriptor", "old-arena");
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    writeFileSync(paths.backupDescriptor, "old-descriptor");
    writeFileSync(paths.journal, `${JSON.stringify(journal(paths, "preparing"))}\n`);
    recoverPublication(paths.journal);
    assertPair(paths, "old-descriptor", "old-arena");
    assert.equal(nodeFs.existsSync(paths.backupDescriptor), false);
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}

{
  const paths = fixture();
  try {
    rmSync(paths.arena);
    assert.throws(
      () => publishFilePair(entries(paths), paths.journal),
      /refusing to replace a mixed pair/,
    );
    assert.equal(nodeFs.existsSync(paths.journal), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
}
