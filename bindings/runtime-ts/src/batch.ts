// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import {
  assertRuntimeStatus,
  type AgenticAILabRuntime,
  type RuntimeExports,
  unsignedRuntimeStatus,
} from "./runtime.ts";

type BatchExports = RuntimeExports & {
  pfw_arena_register(instanceSlot: number, descriptorPointer: number, arenaSlotPointer: number): number;
  pfw_arena_recycle(instanceSlot: number, arenaSlot: number, expectedGeneration: bigint, nextGeneration: bigint): number;
  pfw_arena_release(instanceSlot: number, arenaSlot: number): number;
  pfw_publish_batch(instanceSlot: number, sessionSlot: number, arenaSlot: number, requestPointer: number, resultPointer: number): number;
  pfw_poll_batch(instanceSlot: number, sessionSlot: number, arenaSlot: number, requestPointer: number, resultPointer: number, leaseSlotPointer: number): number;
  pfw_submit_batch(instanceSlot: number, sessionSlot: number, arenaSlot: number, requestPointer: number, resultPointer: number): number;
  pfw_batch_ack(instanceSlot: number, sessionSlot: number, leaseSlot: number): number;
};

export interface RuntimeEventInput {
  sequence: bigint;
  payload: Uint8Array;
  eventKind?: number;
  flags?: number;
}

export interface RuntimeEvent {
  sequence: bigint;
  eventKind: number;
  flags: number;
  payload: Uint8Array;
}

export interface RuntimeBatchResult {
  publishedCount: bigint;
  acceptedCount: bigint;
  rejectedCount: bigint;
  acceptedWatermark: bigint;
  events: RuntimeEvent[];
}

const align = (value: number, alignment: number): number =>
  Math.ceil(value / alignment) * alignment;

export const runRuntimeBatch = (
  runtime: AgenticAILabRuntime,
  instanceSlot: number,
  sessionSlot: number,
  inputs: readonly RuntimeEventInput[],
): RuntimeBatchResult => {
  if (inputs.length === 0) {
    throw new RangeError("agentic-ai-lab runtime batch requires at least one event");
  }
  const exports = runtime.exports as BatchExports;
  const payloadOffsets: number[] = [];
  let payloadSize = 0;
  for (const input of inputs) {
    payloadSize = align(payloadSize, 16);
    payloadOffsets.push(payloadSize);
    payloadSize += input.payload.byteLength;
  }
  const arenaCapacity = Math.max(4096, align(payloadSize, 4096));
  const bitmapBytes = Math.ceil(inputs.length / 8);
  const sizes = [
    arenaCapacity + 15,
    40,
    4,
    inputs.length * 96,
    64,
    24,
    inputs.length * 96,
    72,
    80,
    4,
    96,
    32,
    inputs.length * 4,
    bitmapBytes,
  ];
  const pointers: number[] = [];
  let arenaSlot = 0;
  let arenaReleased = false;
  let arenaAllocationPointer = 0;
  try {
    for (const size of sizes) {
      const pointer = exports.malloc(size);
      if (pointer === 0) {
        throw new RangeError(`agentic-ai-lab runtime could not allocate ${size} batch bytes`);
      }
      pointers.push(pointer);
    }
    const [
      arenaAllocation,
      arenaDescriptor,
      arenaSlotPointer,
      publishHeaders,
      publishRequest,
      publishResult,
      pollHeaders,
      pollRequest,
      pollResult,
      leaseSlotPointer,
      submitRequest,
      submitResult,
      itemStatuses,
      acceptedBitmap,
    ] = pointers;
    if (pointers.some((pointer) => pointer === undefined)) {
      throw new RangeError("agentic-ai-lab runtime batch allocation plan was incomplete");
    }
    const arenaPointer = align(arenaAllocation!, 16);
    arenaAllocationPointer = arenaAllocation!;
    const bytes = new Uint8Array(exports.memory.buffer);
    const view = new DataView(exports.memory.buffer);
    bytes.fill(0, arenaDescriptor!, arenaDescriptor! + 40);
    bytes.fill(0, publishHeaders!, publishHeaders! + inputs.length * 96);
    bytes.fill(0, pollHeaders!, pollHeaders! + inputs.length * 96);
    bytes.fill(0, publishRequest!, publishRequest! + 64);
    bytes.fill(0, publishResult!, publishResult! + 24);
    bytes.fill(0, pollRequest!, pollRequest! + 72);
    bytes.fill(0, pollResult!, pollResult! + 80);
    bytes.fill(0, submitRequest!, submitRequest! + 96);
    bytes.fill(0, submitResult!, submitResult! + 32);
    bytes.fill(0, itemStatuses!, itemStatuses! + inputs.length * 4);
    bytes.fill(0, acceptedBitmap!, acceptedBitmap! + bitmapBytes);

    view.setUint32(arenaDescriptor!, 40, true);
    view.setUint32(arenaDescriptor! + 4, 16, true);
    view.setUint32(arenaDescriptor! + 8, arenaPointer, true);
    view.setBigUint64(arenaDescriptor! + 16, BigInt(arenaCapacity), true);
    view.setBigUint64(arenaDescriptor! + 24, 1n, true);
    assertRuntimeStatus(
      exports.pfw_arena_register(instanceSlot, arenaDescriptor!, arenaSlotPointer!),
      "arena-register",
    );
    arenaSlot = view.getUint32(arenaSlotPointer!, true);

    for (let index = 0; index < inputs.length; index += 1) {
      const input = inputs[index]!;
      const payloadOffset = payloadOffsets[index]!;
      bytes.set(input.payload, arenaPointer + payloadOffset);
      const header = publishHeaders! + index * 96;
      view.setUint16(header, 1, true);
      view.setUint16(header + 2, input.eventKind ?? 1, true);
      view.setUint32(header + 4, input.flags ?? 0, true);
      view.setBigUint64(header + 8, input.sequence, true);
      view.setBigUint64(header + 24, input.sequence, true);
      view.setBigUint64(header + 40, input.sequence + 100n, true);
      view.setBigUint64(header + 56, input.sequence + 200n, true);
      view.setBigUint64(header + 64, BigInt(payloadOffset), true);
      view.setBigUint64(header + 72, BigInt(input.payload.byteLength), true);
    }

    view.setUint32(publishRequest!, 64, true);
    view.setBigUint64(publishRequest! + 32, 1n, true);
    view.setUint32(publishRequest! + 40, publishHeaders!, true);
    view.setBigUint64(publishRequest! + 48, 96n, true);
    view.setBigUint64(publishRequest! + 56, BigInt(inputs.length), true);
    view.setUint32(publishResult!, 24, true);
    assertRuntimeStatus(
      exports.pfw_publish_batch(
        instanceSlot,
        sessionSlot,
        arenaSlot,
        publishRequest!,
        publishResult!,
      ),
      "publish-batch",
    );

    view.setUint32(pollRequest!, 72, true);
    view.setBigUint64(pollRequest! + 32, 1n, true);
    view.setUint32(pollRequest! + 40, pollHeaders!, true);
    view.setBigUint64(pollRequest! + 48, 96n, true);
    view.setBigUint64(pollRequest! + 56, BigInt(inputs.length), true);
    view.setBigUint64(pollRequest! + 64, BigInt(arenaCapacity), true);
    view.setUint32(pollResult!, 80, true);
    assertRuntimeStatus(
      exports.pfw_poll_batch(
        instanceSlot,
        sessionSlot,
        arenaSlot,
        pollRequest!,
        pollResult!,
        leaseSlotPointer!,
      ),
      "poll-batch",
    );
    const producedCount = Number(view.getBigUint64(pollResult! + 40, true));
    const leaseSlot = view.getUint32(leaseSlotPointer!, true);

    view.setUint32(submitRequest!, 96, true);
    view.setBigUint64(submitRequest! + 32, 1n, true);
    view.setUint32(submitRequest! + 40, pollHeaders!, true);
    view.setBigUint64(submitRequest! + 48, 96n, true);
    view.setBigUint64(submitRequest! + 56, BigInt(producedCount), true);
    view.setUint32(submitRequest! + 64, itemStatuses!, true);
    view.setBigUint64(submitRequest! + 72, BigInt(inputs.length), true);
    view.setUint32(submitRequest! + 80, acceptedBitmap!, true);
    view.setBigUint64(submitRequest! + 88, BigInt(bitmapBytes), true);
    view.setUint32(submitResult!, 32, true);
    assertRuntimeStatus(
      exports.pfw_submit_batch(
        instanceSlot,
        sessionSlot,
        arenaSlot,
        submitRequest!,
        submitResult!,
      ),
      "submit-batch",
    );
    assertRuntimeStatus(
      exports.pfw_batch_ack(instanceSlot, sessionSlot, leaseSlot),
      "batch-ack",
    );
    assertRuntimeStatus(
      exports.pfw_arena_recycle(instanceSlot, arenaSlot, 1n, 2n),
      "arena-recycle",
    );
    assertRuntimeStatus(exports.pfw_arena_release(instanceSlot, arenaSlot), "arena-release");
    arenaReleased = true;

    const events: RuntimeEvent[] = [];
    for (let index = 0; index < producedCount; index += 1) {
      const header = pollHeaders! + index * 96;
      const offset = Number(view.getBigUint64(header + 64, true));
      const length = Number(view.getBigUint64(header + 72, true));
      events.push({
        sequence: view.getBigUint64(header + 8, true),
        eventKind: view.getUint16(header + 2, true),
        flags: view.getUint32(header + 4, true),
        payload: bytes.slice(arenaPointer + offset, arenaPointer + offset + length),
      });
    }
    return {
      publishedCount: view.getBigUint64(publishResult! + 8, true),
      acceptedCount: view.getBigUint64(submitResult! + 8, true),
      rejectedCount: view.getBigUint64(submitResult! + 16, true),
      acceptedWatermark: view.getBigUint64(submitResult! + 24, true),
      events,
    };
  } finally {
    if (arenaSlot !== 0 && !arenaReleased) {
      exports.pfw_session_cancel(instanceSlot, sessionSlot);
      arenaReleased = unsignedRuntimeStatus(
        exports.pfw_arena_release(instanceSlot, arenaSlot),
      ) === 0;
    }
    for (const pointer of pointers) {
      if (pointer !== arenaAllocationPointer || arenaReleased) {
        exports.free(pointer);
      }
    }
  }
};
