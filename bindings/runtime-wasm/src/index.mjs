// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

export const PFW_BUNDLE_SYMBOL_KIND_COMPONENT = 1;
export const PFW_BUNDLE_SYMBOL_KIND_POLICY = 2;

export const PFW_WASM_STATUS_INVALID_ARGUMENT = 0xffff0001;
export const PFW_WASM_STATUS_INVALID_SLOT = 0xffff0002;
export const PFW_WASM_STATUS_SLOT_EXHAUSTED = 0xffff0003;

const COMPONENT_ROW_BYTES = 200;
const EDGE_ROW_BYTES = 80;
const SYMBOL_ROW_BYTES = 32;
const utf8 = new TextDecoder();

const resolveDefaultWasmUrl = () => {
  const url = new URL(import.meta.url);
  url.pathname = url.pathname.replace(/[^/]*$/, "agentic_ai_lab_runtime.wasm");
  return url;
};

const toBytes = (value) => {
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  return new Uint8Array(value);
};

const instantiate = async ({ bytes, fetch: fetchImplementation, url } = {}) => {
  const imports = { env: { emscripten_notify_memory_growth() {} } };
  if (bytes != null) return WebAssembly.instantiate(bytes, imports);
  const fetchWasm = fetchImplementation ?? globalThis.fetch;
  if (typeof fetchWasm !== "function") {
    throw new Error("PFW-WASM-E001 fetch is unavailable; provide bytes or fetch");
  }
  const response = await fetchWasm(url ?? resolveDefaultWasmUrl());
  if (!response.ok) {
    throw new Error(`PFW-WASM-E002 failed to load runtime: ${response.status}`);
  }
  if (typeof WebAssembly.instantiateStreaming === "function") {
    return WebAssembly.instantiateStreaming(response, imports);
  }
  return WebAssembly.instantiate(await response.arrayBuffer(), imports);
};

const assertStatus = (status, operation) => {
  const normalized = status >>> 0;
  if (normalized !== 0) {
    throw new Error(`PFW-WASM-E003 ${operation} failed with status 0x${normalized.toString(16)}`);
  }
};

const compactId = (view, offset) => {
  const high = view.getBigUint64(offset, true);
  const low = view.getBigUint64(offset + 8, true);
  return {
    high,
    low,
    key: `${high.toString(16).padStart(16, "0")}${low.toString(16).padStart(16, "0")}`,
  };
};

const allocate = (exports, byteLength) => {
  const pointer = exports.malloc(byteLength);
  if (pointer === 0) throw new Error("PFW-WASM-E005 allocation failed");
  return pointer;
};

class WorkflowCursorSession {
  #exports;
  #handle;
  #stepCount;
  #released = false;

  constructor(exports, handle, stepCount) {
    this.#exports = exports;
    this.#handle = handle;
    this.#stepCount = stepCount;
  }

  get stepCount() {
    return this.#stepCount;
  }

  get released() {
    return this.#released;
  }

  #withU32(count, operation) {
    if (this.#released) throw new Error("PFW-WASM-E004 cursor has been released");
    const pointer = allocate(this.#exports, count * Uint32Array.BYTES_PER_ELEMENT);
    try {
      assertStatus(operation(pointer), "workflow cursor operation");
      return new Uint32Array(this.#exports.memory.buffer, pointer, count).slice();
    } finally {
      this.#exports.free(pointer);
    }
  }

  position() {
    const values = this.#withU32(2, (pointer) =>
      this.#exports.pfw_workflow_cursor_position(this.#handle, pointer, pointer + 4),
    );
    return { completedSteps: values[0], stepCount: values[1] };
  }

  step() {
    const values = this.#withU32(1, (pointer) =>
      this.#exports.pfw_workflow_cursor_step(this.#handle, pointer),
    );
    return { completedSteps: values[0], stepCount: this.#stepCount };
  }

  reset() {
    if (this.#released) throw new Error("PFW-WASM-E004 cursor has been released");
    assertStatus(this.#exports.pfw_workflow_cursor_reset(this.#handle), "cursor reset");
    return { completedSteps: 0, stepCount: this.#stepCount };
  }

  release() {
    if (this.#released) return;
    assertStatus(this.#exports.pfw_workflow_cursor_release(this.#handle), "cursor release");
    this.#released = true;
  }
}

export class AgenticAILabTopology {
  #exports;
  #handle;
  #released = false;

  constructor(exports, handle) {
    this.#exports = exports;
    this.#handle = handle;
  }

  get released() {
    return this.#released;
  }

  #withU32(operation) {
    if (this.#released) throw new Error("PFW-WASM-E007 topology has been released");
    const pointer = allocate(this.#exports, Uint32Array.BYTES_PER_ELEMENT);
    try {
      assertStatus(operation(pointer), "topology query");
      return new Uint32Array(this.#exports.memory.buffer, pointer, 1)[0];
    } finally {
      this.#exports.free(pointer);
    }
  }

  #row(byteLength, operation) {
    if (this.#released) throw new Error("PFW-WASM-E007 topology has been released");
    const pointer = allocate(this.#exports, byteLength);
    try {
      assertStatus(operation(pointer), "topology row query");
      return new Uint8Array(this.#exports.memory.buffer, pointer, byteLength).slice();
    } finally {
      this.#exports.free(pointer);
    }
  }

  get componentCount() {
    return this.#withU32((pointer) =>
      this.#exports.pfw_topology_component_count(this.#handle, pointer),
    );
  }

  get edgeCount() {
    return this.#withU32((pointer) =>
      this.#exports.pfw_topology_edge_count(this.#handle, pointer),
    );
  }

  get symbolCount() {
    return this.#withU32((pointer) =>
      this.#exports.pfw_topology_symbol_count(this.#handle, pointer),
    );
  }

  componentAt(index) {
    const row = this.#row(COMPONENT_ROW_BYTES, (pointer) =>
      this.#exports.pfw_topology_component_at(this.#handle, index, pointer),
    );
    const view = new DataView(row.buffer, row.byteOffset, row.byteLength);
    return {
      caseId: compactId(view, 0),
      componentId: compactId(view, 16),
      objectId: compactId(view, 32),
      typeId: compactId(view, 48),
      contractId: compactId(view, 64),
      roleId: compactId(view, 80),
      capabilityId: compactId(view, 96),
      policyId: compactId(view, 112),
      strategyId: compactId(view, 128),
      adapterId: compactId(view, 144),
      projectionId: compactId(view, 160),
      compositionOrder: view.getBigUint64(176, true),
      flags: view.getUint32(184, true),
    };
  }

  edgeAt(index) {
    const row = this.#row(EDGE_ROW_BYTES, (pointer) =>
      this.#exports.pfw_topology_edge_at(this.#handle, index, pointer),
    );
    const view = new DataView(row.buffer, row.byteOffset, row.byteLength);
    return {
      caseId: compactId(view, 0),
      sourceComponentId: compactId(view, 16),
      targetComponentId: compactId(view, 32),
      relationId: compactId(view, 48),
      compositionOrder: view.getBigUint64(64, true),
      flags: view.getUint32(72, true),
    };
  }

  symbolAt(index) {
    const row = this.#row(SYMBOL_ROW_BYTES, (pointer) =>
      this.#exports.pfw_topology_symbol_at(this.#handle, index, pointer),
    );
    const view = new DataView(row.buffer, row.byteOffset, row.byteLength);
    const id = compactId(view, 0);
    const offset = Number(view.getBigUint64(16, true));
    const length = view.getUint32(24, true);
    const pointer = allocate(this.#exports, length || 1);
    try {
      assertStatus(
        this.#exports.pfw_topology_metadata_copy(this.#handle, offset, length, pointer),
        "topology symbol bytes",
      );
      const bytes = new Uint8Array(this.#exports.memory.buffer, pointer, length).slice();
      return {
        id,
        value: utf8.decode(bytes),
        kind: view.getUint16(28, true),
        flags: view.getUint16(30, true),
      };
    } finally {
      this.#exports.free(pointer);
    }
  }

  components() {
    return Array.from({ length: this.componentCount }, (_, index) => this.componentAt(index));
  }

  edges() {
    return Array.from({ length: this.edgeCount }, (_, index) => this.edgeAt(index));
  }

  symbols() {
    return Array.from({ length: this.symbolCount }, (_, index) => this.symbolAt(index));
  }

  policyForComponent(component) {
    return this.symbols().find(
      (symbol) => symbol.kind === PFW_BUNDLE_SYMBOL_KIND_POLICY && symbol.id.key === component.policyId.key,
    ) ?? null;
  }

  openCursor() {
    const stepCount = this.componentCount;
    const handle = this.#withU32((pointer) =>
      this.#exports.pfw_workflow_cursor_open(this.#handle, pointer),
    );
    return new WorkflowCursorSession(this.#exports, handle, stepCount);
  }

  release() {
    if (this.#released) return;
    assertStatus(this.#exports.pfw_topology_release(this.#handle), "topology release");
    this.#released = true;
  }
}

export class AgenticAILabWasmRuntime {
  #exports;

  constructor(exports) {
    this.#exports = exports;
  }

  get handleCapacity() {
    return this.#exports.pfw_handle_capacity();
  }

  get workflowCursorCapacity() {
    return this.#exports.pfw_workflow_cursor_capacity();
  }

  openTopology({ descriptor, arena }) {
    const descriptorBytes = toBytes(descriptor);
    const arenaBytes = toBytes(arena);
    const descriptorPointer = allocate(this.#exports, descriptorBytes.byteLength);
    const arenaPointer = allocate(this.#exports, arenaBytes.byteLength || 1);
    const handlePointer = allocate(this.#exports, Uint32Array.BYTES_PER_ELEMENT);
    try {
      new Uint8Array(
        this.#exports.memory.buffer,
        descriptorPointer,
        descriptorBytes.byteLength,
      ).set(descriptorBytes);
      new Uint8Array(this.#exports.memory.buffer, arenaPointer, arenaBytes.byteLength).set(arenaBytes);
      assertStatus(
        this.#exports.pfw_topology_open_packed(
          descriptorPointer,
          descriptorBytes.byteLength,
          arenaPointer,
          arenaBytes.byteLength,
          handlePointer,
        ),
        "topology open",
      );
      const handle = new Uint32Array(this.#exports.memory.buffer, handlePointer, 1)[0];
      return new AgenticAILabTopology(this.#exports, handle);
    } finally {
      this.#exports.free(handlePointer);
      this.#exports.free(arenaPointer);
      this.#exports.free(descriptorPointer);
    }
  }
}

export const loadAgenticAILabWasmRuntime = async (options) => {
  const instantiated = await instantiate(options);
  return new AgenticAILabWasmRuntime(instantiated.instance.exports);
};
