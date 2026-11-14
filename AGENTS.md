<!--
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
-->

# Agentic AI Lab Project Rules

## Core Invariants

- Public extension and module APIs must be 100% POO. Expose Gerbil POO objects, prototype composition, slot operators, and object extension helpers as the normal path.
- Prefer functional programming style in the Scheme semantic runtime. Flow composition should be expressed as pure values and functional combinators first; side effects belong behind explicit runtime or Marlin handoff boundaries.
- Funflow is here to anchor that functional route. The project core is POO + functional programming, and new features must preserve that direction.
- Do not make raw alist DSLs, record DSLs, ad hoc patch languages, or raw `(lambda (self super) ...)` compute hooks the ordinary user interface. Advanced escape hatches may exist only behind named POO or functional helpers.
- Follow the current project programming style in `core/module-system/design/44-current-project-programming-style.org`. Use Gerbil declarative macros, procedural macros, and bounded compile-time metaprogramming for repeated internal POO object families, contract projections, and manifest declarations when they expand to ordinary POO or functional code.
- Gerbil macro governance must be constrained by the POO core: functions and runtime `gerbil-poo` objects/prototypes are the default abstractions, while the small RFC-reviewed public macro surface may only project necessary hygienic syntax or phase semantics onto ordinary POO and functional code.
- Security inference APIs must preserve competing hypotheses, their evidence lineage, contradictions, and open questions. Do not reduce them to a hard-coded "next" step, a favored attack path, or a likelihood inferred from missing-claim counts. Accept bounded POO branches proposed by investigators or Agents and evaluate every branch against every hypothesis. Hypothetical model fit never authenticates evidence, establishes historical attribution, grants tool execution, or authorizes an effect.

## Development Tests

- Put Lab module suites in `t/yanxu/<Renamer-or-Loader-directory>/<module-name>/*-test.ss`. Use the module's Loader declaration to determine the owner. Keep test fixtures and generated inputs outside the Loader test tree. Run `just test-lab-layout` after adding or moving a suite.
- Keep Lab suites on public Yuanxu interfaces. Yuanxu's own loader, compiler and publication fixtures belong in the Core repository. Lab owns downstream consumer assertions and their fixtures.
- Put suites spanning multiple packages or components in `t/integration/` and invoke them through their maintained Just recipes. Keep historical qualification evidence bound to its original source paths. The Lab runtime entry `just test-root` runs the layout contract before starting the test harness.

- Build input context is owned by Yuanxu's init/build projection. Do not fix cold/hot regressions by changing downstream `GERBIL_LOADPATH` ordering, warming scopes before projection, bypassing native compiler Context authentication, or increasing timeouts. Use the existing `call-with-build-input-path` boundary; preserve caller order on exit and refuse an epoch after input-context mutation.
- Normal `.get` acceptance must use the existing callback-free operation counters, including owner-qualified `scope-factory` counts. An open source observer is an adversarial effect boundary and changes replay behavior; keep those controls separate from normal EVAL timing. Do not remove the corresponding mutation/callback tests.
- Changes to module resolution or projection must pass Core `just test-build-input-context-mutations <artifact-dir>` (including order/admission suites before and after isolated faults), plus Lab `t/yanxu/modules/services/opentofu/deployment-test.ss`. A timeout or compiler failure does not count as rejecting a mutation. The Lab gate deliberately supplies output-first paths to every action, verifies stable compiler prerequisites, and requires runtime/tests to consume B products. Source projection must construct zero business scopes; the independent B runtime retains all first `.get` assertions. Keep the 120-second aggregate and 120/60-second action/idle budgets.

- Run Gerbil/Scheme tests through the Justfile heap-fenced entrypoints: `just test-file <path>` for one test and `just test` for the full suite. Do not launch raw `gxtest`, `gxi`, or `gerbil test` for project tests; those commands omit this project's pre-import heap limit.
- Run focused Gerbil tests serially unless the scheduler enforces an aggregate memory budget. Each process can use its own heap allowance.
- Add a Just recipe with `gerbil_test_runtime_options` and a timeout before importing Scheme modules if a test needs a different launcher.
- Inspect the focused test output before reporting success: require `MODULE-OK`, `HARNESS-OK`, a final `OK`, and no `ERROR CASE`, `ERROR CHECK`, `ERROR HARNESS`, `Heap overflow`, or `Stack overflow` marker. Gerbil can exit with code 0 after a harness failure.

## Execution artifacts

- Do not commit raw build/test/qualification logs or compressed logs. Keep them in local or CI artifacts; source control holds executable gates and structured summaries.
