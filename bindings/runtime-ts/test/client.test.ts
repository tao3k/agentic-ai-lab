// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";
import test from "node:test";

import { RuntimeWorkerClient, type RuntimeWorkerTransport } from "../src/client.ts";
import type { RuntimeWorkerRequest, RuntimeWorkerResponse } from "../src/protocol.ts";
import { PFW_WASM_STATUS_INVALID_SLOT, AgenticAILabRuntimeError } from "../src/runtime.ts";

class FakeTransport implements RuntimeWorkerTransport {
  readonly messages: RuntimeWorkerRequest[] = [];
  private listener: ((event: MessageEvent<RuntimeWorkerResponse>) => void) | undefined;
  terminated = false;

  postMessage(message: RuntimeWorkerRequest): void {
    this.messages.push(message);
  }

  addEventListener(
    _type: "message",
    listener: (event: MessageEvent<RuntimeWorkerResponse>) => void,
  ): void {
    this.listener = listener;
  }

  removeEventListener(
    _type: "message",
    listener: (event: MessageEvent<RuntimeWorkerResponse>) => void,
  ): void {
    if (this.listener === listener) {
      this.listener = undefined;
    }
  }

  terminate(): void {
    this.terminated = true;
  }

  respond(response: RuntimeWorkerResponse): void {
    this.listener?.({ data: response } as MessageEvent<RuntimeWorkerResponse>);
  }
}

test("worker client correlates out-of-order responses", async () => {
  const transport = new FakeTransport();
  const client = new RuntimeWorkerClient(transport);
  const first = client.request({ kind: "instance-create" });
  const second = client.request({ kind: "instance-create" });
  transport.respond({ id: 2, ok: true, kind: "instance-created", slot: 22 });
  transport.respond({ id: 1, ok: true, kind: "instance-created", slot: 11 });
  assert.equal((await first).kind, "instance-created");
  assert.equal((await second).kind, "instance-created");
  client.close();
  assert.equal(transport.terminated, true);
});

test("worker client converts runtime error responses", async () => {
  const transport = new FakeTransport();
  const client = new RuntimeWorkerClient(transport);
  const response = client.request({ kind: "instance-release", slot: 99 });
  transport.respond({
    id: 1,
    ok: false,
    kind: "error",
    message: "invalid slot",
    status: PFW_WASM_STATUS_INVALID_SLOT,
  });
  await assert.rejects(
    response,
    (error) =>
      error instanceof AgenticAILabRuntimeError && error.status === PFW_WASM_STATUS_INVALID_SLOT,
  );
  client.close();
});
