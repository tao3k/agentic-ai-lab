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

Downstream projects own their composition source as Scheme. The public Bazel
rule keeps lowering in the host build and emits immutable files for this browser
runtime:

```starlark
load("@agentic_ai_lab//packages/bazel:bundle_v1.bzl", "agentic_ai_lab_bundle_v1")

agentic_ai_lab_bundle_v1(
    name = "principles_bundle",
    src = "human-capability.ss",
    arena_out = "human-capability.arena.bin",
    bundle_id = "human-capability",
    descriptor_out = "human-capability.descriptor.bin",
)
```

The Scheme entrypoint calls
`agentic-ai-lab-write-composition-bundle-v1/from-environment!` with its composed POO
value. Bazel supplies the bundle identity and declared output paths. No Scheme
compiler or lowering implementation is added to the browser WASM surface.


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
