// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const loadRuntime = async () => {
  const bytes = await readFile(new URL("../dist/agentic_ai_lab_runtime.wasm", import.meta.url));
  const { instance } = await WebAssembly.instantiate(bytes, {
    env: { emscripten_notify_memory_growth: () => undefined },
  });
  return instance.exports;
};

const loadTopologyFixture = async () => {
  const [descriptor, arena] = await Promise.all([
    readFile(new URL("../workflows/human-capability.descriptor.bin", import.meta.url)),
    readFile(new URL("../workflows/human-capability.arena.bin", import.meta.url)),
  ]);
  return { descriptor, arena };
};

test("standalone runtime creates and releases an instance through slots", async () => {
  const runtime = await loadRuntime();
  assert.equal(typeof runtime.memory, "object");
  assert.equal(runtime.pfw_handle_capacity(), 1023);

  const slotPointer = runtime.malloc(4);
  assert.notEqual(slotPointer, 0);
  try {
    assert.equal(runtime.pfw_instance_create(slotPointer), 0);
    const slot = new DataView(runtime.memory.buffer).getUint32(slotPointer, true);
    assert.ok(slot > 0);
    assert.equal(runtime.pfw_instance_release(slot), 0);
    assert.equal(runtime.pfw_instance_release(slot) >>> 0, 0xffff0002);
  } finally {
    runtime.free(slotPointer);
  }
});

test("workflow cursor advances, saturates, resets, and releases", async () => {
  const exports = await loadRuntime();
  const { descriptor, arena } = await loadTopologyFixture();
  const descriptorPointer = exports.malloc(descriptor.byteLength);
  const arenaPointer = exports.malloc(arena.byteLength);
  const pointer = exports.malloc(8);
  assert.notEqual(descriptorPointer, 0);
  assert.notEqual(arenaPointer, 0);
  new Uint8Array(exports.memory.buffer, descriptorPointer, descriptor.byteLength).set(descriptor);
  new Uint8Array(exports.memory.buffer, arenaPointer, arena.byteLength).set(arena);

  try {
    assert.equal(
      exports.pfw_topology_open_packed(
        descriptorPointer,
        descriptor.byteLength,
        arenaPointer,
        arena.byteLength,
        pointer,
      ),
      0,
    );
    const topologyHandle = new Uint32Array(exports.memory.buffer, pointer, 1)[0];
    assert.equal(exports.pfw_topology_component_count(topologyHandle, pointer), 0);
    assert.equal(new Uint32Array(exports.memory.buffer, pointer, 1)[0], 11);
    assert.equal(exports.pfw_topology_edge_count(topologyHandle, pointer), 0);
    assert.equal(new Uint32Array(exports.memory.buffer, pointer, 1)[0], 15);
    assert.equal(exports.pfw_topology_symbol_count(topologyHandle, pointer), 0);
    assert.equal(new Uint32Array(exports.memory.buffer, pointer, 1)[0], 21);

    assert.equal(exports.pfw_workflow_cursor_capacity(), 1023);
    assert.equal(exports.pfw_workflow_cursor_open(topologyHandle, pointer), 0);
    const cursorHandle = new Uint32Array(exports.memory.buffer, pointer, 1)[0];
    assert.notEqual(cursorHandle, 0);

    assert.equal(exports.pfw_workflow_cursor_position(cursorHandle, pointer, pointer + 4), 0);
    assert.deepEqual([...new Uint32Array(exports.memory.buffer, pointer, 2)], [0, 11]);

    for (const completedSteps of [1, 2, 3]) {
      assert.equal(exports.pfw_workflow_cursor_step(cursorHandle, pointer), 0);
      assert.equal(new Uint32Array(exports.memory.buffer, pointer, 1)[0], completedSteps);
    }

    assert.equal(exports.pfw_workflow_cursor_reset(cursorHandle), 0);
    assert.equal(exports.pfw_workflow_cursor_position(cursorHandle, pointer, pointer + 4), 0);
    assert.deepEqual([...new Uint32Array(exports.memory.buffer, pointer, 2)], [0, 11]);

    assert.equal(exports.pfw_workflow_cursor_release(cursorHandle), 0);
    assert.equal(exports.pfw_workflow_cursor_release(cursorHandle) >>> 0, 0xffff0002);
    assert.equal(exports.pfw_topology_release(topologyHandle), 0);
  } finally {
    exports.free(pointer);
    exports.free(arenaPointer);
    exports.free(descriptorPointer);
  }
});

test("ESM runtime exposes Bundle v1 topology and its cursor", async () => {
  const [{ loadAgenticAILabWasmRuntime, PFW_BUNDLE_SYMBOL_KIND_POLICY }, bytes, fixture] = await Promise.all([
    import("../dist/index.mjs"),
    readFile(new URL("../dist/agentic_ai_lab_runtime.wasm", import.meta.url)),
    loadTopologyFixture(),
  ]);
  const runtime = await loadAgenticAILabWasmRuntime({ bytes });
  const descriptorBacking = new Uint8Array(fixture.descriptor.byteLength + 4);
  const arenaBacking = new Uint8Array(fixture.arena.byteLength + 4);
  descriptorBacking.set(fixture.descriptor, 2);
  arenaBacking.set(fixture.arena, 2);
  const topology = runtime.openTopology({
    descriptor: descriptorBacking.subarray(2, 2 + fixture.descriptor.byteLength),
    arena: arenaBacking.subarray(2, 2 + fixture.arena.byteLength),
  });
  const session = topology.openCursor();

  assert.equal(topology.componentCount, 11);
  assert.equal(topology.edgeCount, 15);
  assert.equal(topology.symbolCount, 21);
  assert.equal(topology.components().length, 11);
  assert.equal(topology.edges().length, 15);
  const symbolValues = new Set(topology.symbols().map(({ value }) => value));
  for (const componentName of [
    "human-capability",
    "human-capability-cycle",
    "knowledge",
    "access",
    "understand",
    "compose",
    "governed-action",
    "qualify",
    "act",
    "evidence-return",
    "learn",
  ]) {
    assert.ok(symbolValues.has(componentName));
  }
  assert.ok(symbolValues.has("(all (qualification admitted) (authority human))"));
  const policies = topology.components().map((component) => topology.policyForComponent(component));
  assert.equal(policies.filter(Boolean).length, 10);
  assert.ok(policies.some(({ value }) => value === "(all (qualification admitted) (authority human))"));
  assert.deepEqual(session.position(), { completedSteps: 0, stepCount: 11 });
  assert.deepEqual(session.step(), { completedSteps: 1, stepCount: 11 });
  assert.deepEqual(session.reset(), { completedSteps: 0, stepCount: 11 });
  session.release();
  session.release();
  assert.equal(session.released, true);
  topology.release();
  assert.equal(topology.released, true);
});
