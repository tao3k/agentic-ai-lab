<!--
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
-->

# `@agentic-ai-lab/runtime-wasm`

Browser WebAssembly runtime for canonical Agentic AI Lab Bundle v1 topologies.

Scheme compositions lower to the language-neutral execution plan and Bundle v1
tables. The package ships the resulting immutable descriptor and arena bytes;
the WASM runtime validates and owns topology queries and cursor state. JavaScript
and TypeScript provide binding APIs only and do not regenerate workflow meaning.

## Exports

- `@agentic-ai-lab/runtime-wasm`: runtime loader, topology queries, and cursor API
- `@agentic-ai-lab/runtime-wasm/wasm`: packaged WebAssembly module
- `@agentic-ai-lab/runtime-wasm/workflows/human-capability/descriptor`: Bundle v1 descriptor
- `@agentic-ai-lab/runtime-wasm/workflows/human-capability/arena`: immutable Bundle v1 arena

The package payload is built and tested from the Agentic AI Lab source repository.
Generated `dist/`, Bundle assets, and package archives are published from the
independent `npm-package` branch and are not committed to `main`.

## Downstream Scheme compositions

Downstream projects own their composition source as Scheme. Generate immutable
descriptor and arena files through the native Gerbil entrypoint:

```sh
AGENTIC_AI_LAB_BUNDLE_V1_ID=principles \
AGENTIC_AI_LAB_BUNDLE_V1_EPOCH=1 \
YUANXU_BUNDLE_V1_DESCRIPTOR_OUT=principles.descriptor.bin \
YUANXU_BUNDLE_V1_ARENA_OUT=principles.arena.bin \
  gerbil env gerbil human-capability.ss
```

The Scheme entrypoint calls
`agentic-ai-lab-write-composition-bundle-v1/from-environment!` with its composed
POO value. The browser consumes those bytes without a Scheme compiler. The npm
build performs two independent native generations and compares both outputs
before publishing them.


## Guard metadata

A profile `:guard` or a stage `(guard …)` is compiled into a Bundle policy
symbol. `component.policyId` identifies that immutable symbol;
`topology.policyForComponent(component)` resolves it without reconstructing the
Scheme composition in JavaScript. A policy symbol describes an admission
condition only. Browser WASM does not evaluate arbitrary Scheme or issue an
admission receipt; Marlin/qualify remains the execution and evidence owner.

```ts
const component = topology.componentAt(4);
const policy = topology.policyForComponent(component);
if (policy?.kind === PFW_BUNDLE_SYMBOL_KIND_POLICY) {
  renderGuard(policy.value); // canonical Scheme condition text
}
```

`PFW_BUNDLE_SYMBOL_KIND_COMPONENT` and `PFW_BUNDLE_SYMBOL_KIND_POLICY` are the
public symbol-kind constants; consumers should not depend on numeric literals.
