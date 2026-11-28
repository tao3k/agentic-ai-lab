// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

export const PFW_WASM_STATUS_INVALID_ARGUMENT = 0xffff0001;
export const PFW_WASM_STATUS_INVALID_SLOT = 0xffff0002;
export const PFW_WASM_STATUS_SLOT_EXHAUSTED = 0xffff0003;

export type RuntimeExports = WebAssembly.Exports & {
  memory: WebAssembly.Memory;
  malloc(size: number): number;
  free(pointer: number): void;
  pfw_handle_capacity(): number;
  pfw_instance_create(slotPointer: number): number;
  pfw_instance_release(slot: number): number;
  pfw_negotiate(instanceSlot: number, requestPointer: number, resultPointer: number, profileSlotPointer: number): number;
  pfw_profile_release(instanceSlot: number, profileSlot: number): number;
  pfw_bundle_open(instanceSlot: number, profileSlot: number, descriptorPointer: number, bundleSlotPointer: number): number;
  pfw_bundle_release(instanceSlot: number, bundleSlot: number): number;
  pfw_session_open(instanceSlot: number, bundleSlot: number, descriptorPointer: number, sessionSlotPointer: number): number;
  pfw_session_cancel(instanceSlot: number, sessionSlot: number): number;
  pfw_session_close(instanceSlot: number, sessionSlot: number, disposition: number): number;
  pfw_session_release(instanceSlot: number, sessionSlot: number): number;
};

export interface RuntimeNegotiation {
  profileSlot: number;
  abiMajor: number;
  abiMinor: number;
  capabilities: bigint;
  concurrencyProfile: number;
  maxPayloadBytes: bigint;
}

export interface RuntimeNegotiationOptions {
  bundleSchema?: string;
  runtimeIdentity?: string;
  requiredCapabilities?: bigint;
  optionalCapabilities?: bigint;
  concurrencyProfile?: number;
  maxPayloadBytes?: bigint;
}

export interface RuntimeBundleOptions {
  schema?: string;
  canonicalPacket?: Uint8Array;
  digest?: Uint8Array;
  digestAlgorithm?: number;
  bundleEpoch?: bigint;
}

export class AgenticAILabRuntimeError extends Error {
  readonly status: number;

  constructor(status: number, operation: string) {
    super(`${operation} failed with runtime status 0x${status.toString(16).padStart(8, "0")}`);
    this.name = "AgenticAILabRuntimeError";
    this.status = status;
  }
}

export const unsignedRuntimeStatus = (status: number): number => status >>> 0;

export const assertRuntimeStatus = (status: number, operation: string): void => {
  const normalized = unsignedRuntimeStatus(status);
  if (normalized !== 0) {
    throw new AgenticAILabRuntimeError(normalized, operation);
  }
};

export class AgenticAILabRuntime {
  readonly exports: RuntimeExports;

  private constructor(exports: RuntimeExports) {
    this.exports = exports;
  }

  static async instantiate(bytes: BufferSource): Promise<AgenticAILabRuntime> {
    const { instance } = await WebAssembly.instantiate(bytes, {
      env: { emscripten_notify_memory_growth: () => undefined },
    });
    const exports = instance.exports as RuntimeExports;
    if (!(exports.memory instanceof WebAssembly.Memory)) {
      throw new TypeError("agentic-ai-lab runtime does not export WebAssembly memory");
    }
    return new AgenticAILabRuntime(exports);
  }

  static async fetch(url: string | URL): Promise<AgenticAILabRuntime> {
    const response = await globalThis.fetch(url);
    if (!response.ok) {
      throw new Error(`failed to fetch agentic-ai-lab runtime: ${response.status}`);
    }
    return AgenticAILabRuntime.instantiate(await response.arrayBuffer());
  }

  get handleCapacity(): number {
    return this.exports.pfw_handle_capacity() >>> 0;
  }

  private allocateMany(sizes: readonly number[]): number[] {
    const pointers: number[] = [];
    try {
      for (const size of sizes) {
        const pointer = this.exports.malloc(size);
        if (pointer === 0) {
          throw new RangeError(`agentic-ai-lab runtime could not allocate ${size} bytes`);
        }
        pointers.push(pointer);
      }
      return pointers;
    } catch (error) {
      for (const pointer of pointers) {
        this.exports.free(pointer);
      }
      throw error;
    }
  }

  private freeMany(pointers: readonly number[]): void {
    for (const pointer of pointers) {
      this.exports.free(pointer);
    }
  }

  createInstance(): number {
    const slotPointer = this.exports.malloc(4);
    if (slotPointer === 0) {
      throw new RangeError("agentic-ai-lab runtime could not allocate an instance slot pointer");
    }
    try {
      assertRuntimeStatus(this.exports.pfw_instance_create(slotPointer), "instance-create");
      return new DataView(this.exports.memory.buffer).getUint32(slotPointer, true);
    } finally {
      this.exports.free(slotPointer);
    }
  }

  releaseInstance(slot: number): void {
    assertRuntimeStatus(this.exports.pfw_instance_release(slot), "instance-release");
  }

  negotiate(instanceSlot: number, options: RuntimeNegotiationOptions = {}): RuntimeNegotiation {
    const encoder = new TextEncoder();
    const schema = encoder.encode(options.bundleSchema ?? "agentic-ai-lab.organization-bundle.draft.3");
    const identity = encoder.encode(options.runtimeIdentity ?? "runtime-ts");
    const pointers = this.allocateMany([72, 56, 4, schema.byteLength, identity.byteLength]);
    const [requestPointer, resultPointer, profileSlotPointer, schemaPointer, identityPointer] = pointers;
    if (
      requestPointer === undefined ||
      resultPointer === undefined ||
      profileSlotPointer === undefined ||
      schemaPointer === undefined ||
      identityPointer === undefined
    ) {
      this.freeMany(pointers);
      throw new RangeError("agentic-ai-lab runtime allocation plan was incomplete");
    }
    try {
      const bytes = new Uint8Array(this.exports.memory.buffer);
      const view = new DataView(this.exports.memory.buffer);
      bytes.fill(0, requestPointer, requestPointer + 72);
      bytes.fill(0, resultPointer, resultPointer + 56);
      bytes.set(schema, schemaPointer);
      bytes.set(identity, identityPointer);
      view.setUint32(requestPointer, 72, true);
      view.setUint16(requestPointer + 4, 0, true);
      view.setUint16(requestPointer + 6, 1, true);
      view.setBigUint64(requestPointer + 8, options.requiredCapabilities ?? 0x7dn, true);
      view.setBigUint64(requestPointer + 16, options.optionalCapabilities ?? 0n, true);
      view.setUint32(requestPointer + 24, options.concurrencyProfile ?? 0, true);
      view.setBigUint64(requestPointer + 32, options.maxPayloadBytes ?? 0n, true);
      view.setUint32(requestPointer + 40, schemaPointer, true);
      view.setBigUint64(requestPointer + 48, BigInt(schema.byteLength), true);
      view.setUint32(requestPointer + 56, identityPointer, true);
      view.setBigUint64(requestPointer + 64, BigInt(identity.byteLength), true);
      view.setUint32(resultPointer, 56, true);

      assertRuntimeStatus(
        this.exports.pfw_negotiate(instanceSlot, requestPointer, resultPointer, profileSlotPointer),
        "negotiate",
      );
      return {
        profileSlot: view.getUint32(profileSlotPointer, true),
        abiMajor: view.getUint16(resultPointer + 4, true),
        abiMinor: view.getUint16(resultPointer + 6, true),
        capabilities: view.getBigUint64(resultPointer + 8, true),
        concurrencyProfile: view.getUint32(resultPointer + 16, true),
        maxPayloadBytes: view.getBigUint64(resultPointer + 24, true),
      };
    } finally {
      this.freeMany(pointers);
    }
  }

  releaseProfile(instanceSlot: number, profileSlot: number): void {
    assertRuntimeStatus(this.exports.pfw_profile_release(instanceSlot, profileSlot), "profile-release");
  }

  openBundle(instanceSlot: number, profileSlot: number, options: RuntimeBundleOptions = {}): number {
    const encoder = new TextEncoder();
    const schema = encoder.encode(options.schema ?? "agentic-ai-lab.organization-bundle.draft.3");
    const packet = options.canonicalPacket ?? encoder.encode("bundle");
    const digest = options.digest ?? new Uint8Array(32).fill(0x44);
    if (digest.byteLength !== 32) {
      throw new RangeError("agentic-ai-lab bundle digest must contain exactly 32 bytes");
    }
    const pointers = this.allocateMany([88, 4, schema.byteLength, packet.byteLength]);
    const [descriptorPointer, bundleSlotPointer, schemaPointer, packetPointer] = pointers;
    if (
      descriptorPointer === undefined ||
      bundleSlotPointer === undefined ||
      schemaPointer === undefined ||
      packetPointer === undefined
    ) {
      this.freeMany(pointers);
      throw new RangeError("agentic-ai-lab bundle allocation plan was incomplete");
    }
    try {
      const bytes = new Uint8Array(this.exports.memory.buffer);
      const view = new DataView(this.exports.memory.buffer);
      bytes.fill(0, descriptorPointer, descriptorPointer + 88);
      bytes.set(digest, descriptorPointer + 8);
      bytes.set(schema, schemaPointer);
      bytes.set(packet, packetPointer);
      view.setUint32(descriptorPointer, 88, true);
      view.setUint32(descriptorPointer + 4, options.digestAlgorithm ?? 0, true);
      view.setBigUint64(descriptorPointer + 40, options.bundleEpoch ?? 3n, true);
      view.setUint32(descriptorPointer + 48, schemaPointer, true);
      view.setBigUint64(descriptorPointer + 56, BigInt(schema.byteLength), true);
      view.setUint32(descriptorPointer + 64, packetPointer, true);
      view.setBigUint64(descriptorPointer + 72, BigInt(packet.byteLength), true);
      assertRuntimeStatus(
        this.exports.pfw_bundle_open(instanceSlot, profileSlot, descriptorPointer, bundleSlotPointer),
        "bundle-open",
      );
      return view.getUint32(bundleSlotPointer, true);
    } finally {
      this.freeMany(pointers);
    }
  }

  releaseBundle(instanceSlot: number, bundleSlot: number): void {
    assertRuntimeStatus(this.exports.pfw_bundle_release(instanceSlot, bundleSlot), "bundle-release");
  }

  openSession(instanceSlot: number, bundleSlot: number): number {
    const pointers = this.allocateMany([32, 4]);
    const [descriptorPointer, sessionSlotPointer] = pointers;
    if (descriptorPointer === undefined || sessionSlotPointer === undefined) {
      this.freeMany(pointers);
      throw new RangeError("agentic-ai-lab session allocation plan was incomplete");
    }
    try {
      const bytes = new Uint8Array(this.exports.memory.buffer);
      const view = new DataView(this.exports.memory.buffer);
      bytes.fill(0, descriptorPointer, descriptorPointer + 32);
      view.setUint32(descriptorPointer, 32, true);
      assertRuntimeStatus(
        this.exports.pfw_session_open(instanceSlot, bundleSlot, descriptorPointer, sessionSlotPointer),
        "session-open",
      );
      return view.getUint32(sessionSlotPointer, true);
    } finally {
      this.freeMany(pointers);
    }
  }

  cancelSession(instanceSlot: number, sessionSlot: number): void {
    assertRuntimeStatus(this.exports.pfw_session_cancel(instanceSlot, sessionSlot), "session-cancel");
  }

  closeSession(instanceSlot: number, sessionSlot: number, disposition = 1): void {
    assertRuntimeStatus(
      this.exports.pfw_session_close(instanceSlot, sessionSlot, disposition),
      "session-close",
    );
  }

  releaseSession(instanceSlot: number, sessionSlot: number): void {
    assertRuntimeStatus(this.exports.pfw_session_release(instanceSlot, sessionSlot), "session-release");
  }
}
