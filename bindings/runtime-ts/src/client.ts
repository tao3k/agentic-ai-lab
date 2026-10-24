// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import type { RuntimeWorkerRequest, RuntimeWorkerResponse } from "./protocol.ts";
import { AgenticAILabRuntimeError } from "./runtime.ts";

export type RuntimeWorkerRequestPayload = RuntimeWorkerRequest extends infer Request
  ? Request extends { id: number }
    ? Omit<Request, "id">
    : never
  : never;

export interface RuntimeWorkerTransport {
  postMessage(message: RuntimeWorkerRequest): void;
  addEventListener(type: "message", listener: (event: MessageEvent<RuntimeWorkerResponse>) => void): void;
  removeEventListener(type: "message", listener: (event: MessageEvent<RuntimeWorkerResponse>) => void): void;
  terminate?(): void;
}

type PendingRequest = {
  resolve: (response: RuntimeWorkerResponse) => void;
  reject: (error: Error) => void;
};

export class RuntimeWorkerClient {
  readonly transport: RuntimeWorkerTransport;
  private readonly pending = new Map<number, PendingRequest>();
  private nextId = 1;
  private closed = false;

  constructor(transport: RuntimeWorkerTransport) {
    this.transport = transport;
    this.transport.addEventListener("message", this.handleMessage);
  }

  private readonly handleMessage = (event: MessageEvent<RuntimeWorkerResponse>): void => {
    const response = event.data;
    const pending = this.pending.get(response.id);
    if (pending === undefined) {
      return;
    }
    this.pending.delete(response.id);
    if (!response.ok) {
      pending.reject(
        response.status === undefined
          ? new Error(response.message)
          : new AgenticAILabRuntimeError(response.status, response.message),
      );
      return;
    }
    pending.resolve(response);
  };

  request(payload: RuntimeWorkerRequestPayload): Promise<RuntimeWorkerResponse> {
    if (this.closed) {
      return Promise.reject(new Error("agentic-ai-lab runtime worker client is closed"));
    }
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.transport.postMessage({ id, ...payload } as RuntimeWorkerRequest);
    });
  }

  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    this.transport.removeEventListener("message", this.handleMessage);
    for (const { reject } of this.pending.values()) {
      reject(new Error("agentic-ai-lab runtime worker client closed before receiving a response"));
    }
    this.pending.clear();
    this.transport.terminate?.();
  }
}
