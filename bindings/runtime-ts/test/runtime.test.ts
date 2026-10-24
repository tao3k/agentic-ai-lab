// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  PFW_WASM_STATUS_INVALID_SLOT,
  AgenticAILabRuntime,
  AgenticAILabRuntimeError,
} from "../src/runtime.ts";
import { runRuntimeBatch } from "../src/batch.ts";

const wasmUrl = new URL("../../runtime-wasm/dist/agentic_ai_lab_runtime.wasm", import.meta.url);

test("TypeScript runtime owns instance slots and normalizes status values", async () => {
  const runtime = await AgenticAILabRuntime.instantiate(await readFile(wasmUrl));
  assert.equal(runtime.handleCapacity, 1023);

  const slot = runtime.createInstance();
  assert.ok(slot > 0);
  runtime.releaseInstance(slot);

  assert.throws(
    () => runtime.releaseInstance(slot),
    (error) =>
      error instanceof AgenticAILabRuntimeError && error.status === PFW_WASM_STATUS_INVALID_SLOT,
  );
});

test("TypeScript runtime opens and closes a negotiated session", async () => {
  const runtime = await AgenticAILabRuntime.instantiate(await readFile(wasmUrl));
  const instance = runtime.createInstance();
  const negotiation = runtime.negotiate(instance, { runtimeIdentity: "runtime-ts-test" });
  assert.equal(negotiation.abiMajor, 0);
  assert.equal(negotiation.abiMinor, 1);
  assert.equal(negotiation.capabilities & 0x7dn, 0x7dn);

  const bundle = runtime.openBundle(instance, negotiation.profileSlot);
  const session = runtime.openSession(instance, bundle);
  runtime.closeSession(instance, session);
  runtime.releaseSession(instance, session);
  runtime.releaseBundle(instance, bundle);
  runtime.releaseProfile(instance, negotiation.profileSlot);
  runtime.releaseInstance(instance);
});

test("TypeScript runtime publishes, polls, submits, and acknowledges events", async () => {
  const runtime = await AgenticAILabRuntime.instantiate(await readFile(wasmUrl));
  const instance = runtime.createInstance();
  const negotiation = runtime.negotiate(instance);
  const bundle = runtime.openBundle(instance, negotiation.profileSlot);
  const session = runtime.openSession(instance, bundle);
  const encoder = new TextEncoder();

  const result = runRuntimeBatch(runtime, instance, session, [
    { sequence: 1n, payload: encoder.encode("first-workflow-node") },
    { sequence: 2n, payload: encoder.encode("second-workflow-node") },
  ]);
  assert.equal(result.publishedCount, 2n);
  assert.equal(result.acceptedCount, 2n);
  assert.equal(result.rejectedCount, 0n);
  assert.deepEqual(result.events.map(({ sequence }) => sequence), [1n, 2n]);
  assert.deepEqual(
    result.events.map(({ payload }) => new TextDecoder().decode(payload)),
    ["first-workflow-node", "second-workflow-node"],
  );

  runtime.closeSession(instance, session);
  runtime.releaseSession(instance, session);
  runtime.releaseBundle(instance, bundle);
  runtime.releaseProfile(instance, negotiation.profileSlot);
  runtime.releaseInstance(instance);
});

test("batch failure releases its registered arena before returning the error", async () => {
  const runtime = await AgenticAILabRuntime.instantiate(await readFile(wasmUrl));
  const instance = runtime.createInstance();
  assert.throws(
    () =>
      runRuntimeBatch(runtime, instance, 0xffff, [
        { sequence: 1n, payload: new Uint8Array([1, 2, 3]) },
      ]),
    (error) =>
      error instanceof AgenticAILabRuntimeError && error.status === PFW_WASM_STATUS_INVALID_SLOT,
  );
  runtime.releaseInstance(instance);
});
