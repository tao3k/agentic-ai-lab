// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

export type AgenticAILabWasmLoadOptions = {
  readonly bytes?: BufferSource;
  readonly fetch?: typeof globalThis.fetch;
  readonly url?: string | URL;
};

export type AgenticAILabCompactId = {
  readonly high: bigint;
  readonly low: bigint;
  readonly key: string;
};

export type AgenticAILabTopologyComponent = {
  readonly caseId: AgenticAILabCompactId;
  readonly componentId: AgenticAILabCompactId;
  readonly objectId: AgenticAILabCompactId;
  readonly typeId: AgenticAILabCompactId;
  readonly contractId: AgenticAILabCompactId;
  readonly roleId: AgenticAILabCompactId;
  readonly capabilityId: AgenticAILabCompactId;
  readonly policyId: AgenticAILabCompactId;
  readonly strategyId: AgenticAILabCompactId;
  readonly adapterId: AgenticAILabCompactId;
  readonly projectionId: AgenticAILabCompactId;
  readonly compositionOrder: bigint;
  readonly flags: number;
};

export type AgenticAILabTopologyEdge = {
  readonly caseId: AgenticAILabCompactId;
  readonly sourceComponentId: AgenticAILabCompactId;
  readonly targetComponentId: AgenticAILabCompactId;
  readonly relationId: AgenticAILabCompactId;
  readonly compositionOrder: bigint;
  readonly flags: number;
};

export type AgenticAILabTopologySymbol = {
  readonly id: AgenticAILabCompactId;
  readonly value: string;
  readonly kind: number;
  readonly flags: number;
};

export type WorkflowCursorSnapshot = {
  readonly completedSteps: number;
  readonly stepCount: number;
};

export interface WorkflowCursorSession {
  readonly stepCount: number;
  readonly released: boolean;
  position(): WorkflowCursorSnapshot;
  step(): WorkflowCursorSnapshot;
  reset(): WorkflowCursorSnapshot;
  release(): void;
}

export declare class AgenticAILabTopology {
  constructor(exports: WebAssembly.Exports, handle: number);
  readonly released: boolean;
  readonly componentCount: number;
  readonly edgeCount: number;
  readonly symbolCount: number;
  componentAt(index: number): AgenticAILabTopologyComponent;
  edgeAt(index: number): AgenticAILabTopologyEdge;
  symbolAt(index: number): AgenticAILabTopologySymbol;
  components(): readonly AgenticAILabTopologyComponent[];
  edges(): readonly AgenticAILabTopologyEdge[];
  symbols(): readonly AgenticAILabTopologySymbol[];
  policyForComponent(component: AgenticAILabTopologyComponent): AgenticAILabTopologySymbol | null;
  openCursor(): WorkflowCursorSession;
  release(): void;
}

export declare class AgenticAILabWasmRuntime {
  constructor(exports: WebAssembly.Exports);
  readonly handleCapacity: number;
  readonly workflowCursorCapacity: number;
  openTopology(input: {
    readonly descriptor: BufferSource;
    readonly arena: BufferSource;
  }): AgenticAILabTopology;
}

export declare const PFW_BUNDLE_SYMBOL_KIND_COMPONENT = 1;
export declare const PFW_BUNDLE_SYMBOL_KIND_POLICY = 2;

export declare const PFW_WASM_STATUS_INVALID_ARGUMENT = 0xffff0001;
export declare const PFW_WASM_STATUS_INVALID_SLOT = 0xffff0002;
export declare const PFW_WASM_STATUS_SLOT_EXHAUSTED = 0xffff0003;

export declare const loadAgenticAILabWasmRuntime: (
  options?: AgenticAILabWasmLoadOptions,
) => Promise<AgenticAILabWasmRuntime>;
