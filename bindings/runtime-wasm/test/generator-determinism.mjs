// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";


const packageRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const outputRoot = join(packageRoot, ".build/bundles");

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
