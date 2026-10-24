<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->
<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->

# Cross-round domain evidence

## Implementation and authority

The model receives a whole repository repair problem and uses ordinary source,
edit and execution tools. Python collects executed values. `domain-check` in
`interface/engine-api.ss` calls `applications/domain-evidence.ss` through the
normal CFFI engine. Scheme evaluates exact constraints and stores their relational
consequences through `DomainEvidence` and `EvidenceChain`. The collector does not
supply the checker verdict. Independent hidden tests decide repair acceptance.

An observation identity binds source snapshot, execution receipt, checker version,
contract kind and input values. Retained observations can support later turns on
that snapshot. Editing source clears observations and previous result references.
Checker-qualified mathematical laws remain available after source edits; changing
the checker version clears both laws and observations. The frozen engine library
hash additionally binds the concrete implementation in the real experiment.

This version identifier is a host admission convention, not a general code-hash
attestation. Arbitrary clients can invent observations; the checker cannot prove
that a supplied observation came from actual execution. The local experiment binds
observations to execution logs and freezes its collector and source snapshots.

## Executable contracts

| Feature | Scheme obligation | Observation scope |
| --- | --- | --- |
| Graph update traversal | Inner mutation order equals outer group order filtered by reachable nodes | Actual update body executions, not preliminary loop guards |
| Graph update conservation | Expected read epoch equals observed epoch; after = before - removed; 0 <= removed <= before | Exact supplied nonnegative counters; epoch collection is not generally instrumented |
| Series root precision | For p = x^m u and n != 0, internal precision is P - m/n | Exact rational valuation and observed normalized expansion budget |
| Series term admission | Keep normalized exponent e iff e + m/n < P | Strict boundary; terms at P are excluded, including negative root orders |
| Structural-hole normalization | Each row divides by its own maximum | Receipted floating values serialized as rationals; explicit absolute tolerance 1e-10 |
| Symbolic family coverage | A delegated zero difference witnesses specialization; returning both is redundant | SymPy simplification witness; Scheme does not implement arbitrary symbolic algebra |

Traversal scheduling and read epochs are distinct obligations. Passing a schedule
check does not establish an arbitrary epoch check. Passing a precision check does
not establish every coefficient of an expansion. These checks provide reusable
constraints to model reasoning and retain counterexamples without claiming full
implementation correctness.

## Three-way verification

`DomainEvidence.lean` proves conditional update conservation/nonnegativity,
precision restoration after exact cross multiplication, strict boundary exclusion,
filtered membership and snapshot/checker rejection. It includes generalized rational
numerator/denominator identities. Denominators are validated as positive by Scheme;
Lean arithmetic identities alone do not prove observation admission.

`DomainEvidence.qnt` models observation admission, source replacement and checker
upgrade. Execution claims always bind the current snapshot and checker. Laws can
survive source replacement but must bind the current checker. The local run checks
10,000 traces of 30 transitions; this is bounded exploration, not an exhaustive
state-space proof. Actual Scheme outputs match the Lean and Quint enumerations on
2,400 precision cases and 500 graph-update cases. Rational fractional boundaries
also have direct Scheme qualification cases.

Neither formal artifact proves the Python collectors, JSON transport, CFFI memory
behavior or a whole upstream algorithm. Scheme integration tests cover execution,
component reuse, old-reference rejection, law retention and checker replacement.

## Real comparison and causal boundary

The frozen pilot uses independent root causes from NetworkX row normalization and
SymPy post-condition ODE solution coverage. The original traversal/precision defects
are development qualification inputs only. See the complete
[experiment report](domain-repository-experiment-report.md) for questions, provenance,
qualification, every trajectory and provider usage.

All conditions receive actual execution observations. Fresh Scheme additionally
checks current observations. Retained Scheme adds checked memory and contracts to
later turns; this intervention combines domain support and retrieval, so it cannot
isolate persistence alone. Complete opaque provider history is preserved in every
condition. All additional context input is charged.
Both Scheme conditions also include checked syntactic-reference support on source
reads. Comparisons against ordinary tools measure the combined assistance package;
they cannot isolate domain checks alone.

The primary endpoint is cumulative provider thinking through first independent
acceptance. Failed edits, rejected submissions and repair calls remain in that sum.
Candidate repair is a whole-turn subset after the first assessed failed repair;
it is never added to total thinking again. Uniform 40-turn censoring and unsuccessful
trajectory costs remain visible. Shorter answers and provider cache discounts do
not establish saved reasoning.

Two root causes and two repetitions are a mechanism pilot. Named functions and small
edit scopes limit generalization; recent disclosure does not prove absence from
training or retrieval. No broad 40–50% savings conclusion follows from these tests
without comparable acceptance and sufficient independent task coverage.

## Local reproduction

From the repository root, with the normal CFFI library already built:

```sh
 gerbil test t/qualification/ascent-domain-evidence-test.ss
 PYTHONPATH=python/src python3 -m ascent_test_support.domain_conformance .gerbil/lib/libascent.dylib .cache/ascent/domain-checks
 quint repl --quiet --backend typescript --require packages/proofs/quint/DomainEvidence.qnt::DomainEvidence conformance > .cache/ascent/domain-checks/quint-precision.json
 quint repl --quiet --backend typescript --require packages/proofs/quint/DomainEvidence.qnt::DomainEvidence graphConformance > .cache/ascent/domain-checks/quint-graph.json
 quint run packages/proofs/quint/DomainEvidence.qnt --backend typescript --max-samples 10000 --max-steps 30 --invariant BoundEvidence --seed 1010 --verbosity 1
```

From `packages/proofs/lean`:

```sh
lake env lean --run DomainEvidence.lean ../../../.cache/ascent/domain-checks/scheme-precision.json ../../../.cache/ascent/domain-checks/quint-precision.json ../../../.cache/ascent/domain-checks/scheme-graph.json ../../../.cache/ascent/domain-checks/quint-graph.json
```

The generator only constructs candidate inputs and serializes Scheme verdicts.
Lean and Quint independently enumerate the corresponding expected flags. It does
not assert Python collector correctness. Actual executed collector regressions and
snapshot invalidation have separate local tests.

## Source-qualified candidate acceptance

The primary study's offline candidate audit found a correct ODE repair at turn 11
that was subsequently overwritten by an incorrect repair. A passing domain check
alone does not establish complete code acceptance; the independent selected suite
supplies that authority.

The local study driver now supports `verifyCandidatesOnEdit`. Both ordinary and
Scheme conditions can apply the same independent suite after each admitted edit.
Failed automatic grades remain host-side and do not expose extra hidden-test
feedback. On acceptance, the driver checks current source bytes, copies the
candidate, rechecks copied bytes, records grader identity and selected test scope,
and ends the trajectory. Further edits are rejected. The accepted artifact is a
source-qualified path; no additional model call is needed to select it.

This guard is a host acceptance policy coupled to Scheme domain support. Lean
states stale-source, changed-copy and changed-grader rejection and sealed-edit
rejection. `VerifiedCandidate.qnt` models immutable admission and new-task/grader
invalidation; its separate 10,000-trace local run passed. The actual filesystem,
independent suite and Python driver remain outside a full refinement proof.

The completed real correction validation used four trajectories on the two already
studied roots. All four were accepted and sealed; every artifact byte identity was
checked against its receipt. These are repeated-root correction tests, not four
new holdout questions. The complete report retains the earlier censoring, subsequent
thinking, overwritten correct candidate and per-root thinking regressions.

New repository-study plans enable the candidate guard by default. Earlier frozen
plans and their producer snapshots retain the protocol actually used for their
recorded model calls. The guard's execution branch was validated by the four real
correction trajectories before default plan templates were updated.
