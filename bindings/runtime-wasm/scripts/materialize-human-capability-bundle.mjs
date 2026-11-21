// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import { readFileSync, rmSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

import { execFileSync } from "node:child_process";
import { acquirePublicationLock } from "./publication-lock.mjs";
import {
  publishFilePair,
  stagePublicationFile,
} from "./publication-transaction.mjs";

const packageRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const workspaceRoot = resolve(packageRoot, "../..");
const outputRoot = join(packageRoot, ".build/bundles");
mkdirSync(outputRoot, { recursive: true });
for (const suffix of ["", ".determinism"]) {
  execFileSync("gerbil", ["env", "gerbil", "-:max-heap=1G,debug=q", "interactive",
    "bindings/runtime-wasm/examples/human-capability.ss"], {
    cwd: workspaceRoot,
    stdio: "inherit",
    env: {
      ...process.env,
      AGENTIC_AI_LAB_BUNDLE_V1_ID: "human-capability",
      AGENTIC_AI_LAB_BUNDLE_V1_EPOCH: "1",
      YUANXU_BUNDLE_V1_DESCRIPTOR_OUT: join(outputRoot, `human-capability${suffix}.descriptor.bin`),
      YUANXU_BUNDLE_V1_ARENA_OUT: join(outputRoot, `human-capability${suffix}.arena.bin`),
    },
  });
}

assert.deepEqual(
  readFileSync(join(outputRoot, "human-capability.determinism.descriptor.bin")),
  readFileSync(join(outputRoot, "human-capability.descriptor.bin")),
  "independent descriptor lowering must be byte deterministic",
);
assert.deepEqual(
  readFileSync(join(outputRoot, "human-capability.determinism.arena.bin")),
  readFileSync(join(outputRoot, "human-capability.arena.bin")),
  "independent arena lowering must be byte deterministic",
);

const outputs = [
  ["human-capability.descriptor.bin", "workflows/human-capability.descriptor.bin"],
  ["human-capability.arena.bin", "workflows/human-capability.arena.bin"],
];

const staged = [];
try {
  for (const [sourceName, targetName] of outputs) {
    const source = join(outputRoot, sourceName);
    const destination = join(packageRoot, targetName);
    const temporary = join(
      dirname(destination),
      `.${sourceName}.${process.pid}-${randomUUID()}.tmp`,
    );
    staged.push({ staged: temporary, destination });
    stagePublicationFile(source, temporary);
  }
  const releasePublicationLock = await acquirePublicationLock(packageRoot);
  try {
    publishFilePair(
      staged,
      join(packageRoot, "workflows/.human-capability.publication.json"),
    );
  } finally {
    await releasePublicationLock();
  }
} finally {
  for (const entry of staged) {
    rmSync(entry.staged, { force: true });
  }
}
