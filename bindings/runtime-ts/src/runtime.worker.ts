// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/// <reference lib="webworker" />

import type { RuntimeWorkerRequest, RuntimeWorkerResponse } from "./protocol.ts";
import { runRuntimeBatch } from "./batch.ts";
import { AgenticAILabRuntime, AgenticAILabRuntimeError } from "./runtime.ts";

declare const self: DedicatedWorkerGlobalScope;

let runtime: AgenticAILabRuntime | undefined;

const respond = (response: RuntimeWorkerResponse): void => self.postMessage(response);

self.onmessage = (event: MessageEvent<RuntimeWorkerRequest>) => {
  const request = event.data;
  void (async () => {
    try {
      switch (request.kind) {
        case "load":
          runtime = await AgenticAILabRuntime.fetch(request.wasmUrl);
          respond({ id: request.id, ok: true, kind: "loaded" });
          return;
        case "instance-create": {
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          const slot = runtime.createInstance();
          respond({ id: request.id, ok: true, kind: "instance-created", slot });
          return;
        }
        case "instance-release":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.releaseInstance(request.slot);
          respond({ id: request.id, ok: true, kind: "instance-released", slot: request.slot });
          return;
        case "negotiate": {
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          const negotiation = runtime.negotiate(request.instanceSlot, {
            ...(request.runtimeIdentity === undefined
              ? {}
              : { runtimeIdentity: request.runtimeIdentity }),
          });
          respond({
            id: request.id,
            ok: true,
            kind: "profile-created",
            slot: negotiation.profileSlot,
            abiMajor: negotiation.abiMajor,
            abiMinor: negotiation.abiMinor,
            capabilities: negotiation.capabilities,
          });
          return;
        }
        case "profile-release":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.releaseProfile(request.instanceSlot, request.profileSlot);
          respond({ id: request.id, ok: true, kind: "profile-released", slot: request.profileSlot });
          return;
        case "bundle-open": {
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          const slot = runtime.openBundle(request.instanceSlot, request.profileSlot);
          respond({ id: request.id, ok: true, kind: "bundle-opened", slot });
          return;
        }
        case "bundle-release":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.releaseBundle(request.instanceSlot, request.bundleSlot);
          respond({ id: request.id, ok: true, kind: "bundle-released", slot: request.bundleSlot });
          return;
        case "session-open": {
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          const slot = runtime.openSession(request.instanceSlot, request.bundleSlot);
          respond({ id: request.id, ok: true, kind: "session-opened", slot });
          return;
        }
        case "session-cancel":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.cancelSession(request.instanceSlot, request.sessionSlot);
          respond({ id: request.id, ok: true, kind: "session-cancelled", slot: request.sessionSlot });
          return;
        case "session-close":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.closeSession(request.instanceSlot, request.sessionSlot, request.disposition);
          respond({ id: request.id, ok: true, kind: "session-closed", slot: request.sessionSlot });
          return;
        case "session-release":
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          runtime.releaseSession(request.instanceSlot, request.sessionSlot);
          respond({ id: request.id, ok: true, kind: "session-released", slot: request.sessionSlot });
          return;
        case "batch-run": {
          if (runtime === undefined) {
            throw new Error("agentic-ai-lab runtime is not loaded");
          }
          const result = runRuntimeBatch(
            runtime,
            request.instanceSlot,
            request.sessionSlot,
            request.events,
          );
          respond({ id: request.id, ok: true, kind: "batch-complete", ...result });
          return;
        }
      }
    } catch (error) {
      respond({
        id: request.id,
        ok: false,
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
        ...(error instanceof AgenticAILabRuntimeError ? { status: error.status } : {}),
      });
    }
  })();
};
