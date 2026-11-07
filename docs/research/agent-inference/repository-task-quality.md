<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->
<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->

# Repository Task Quality and Complexity Audit

## Decision and evidence boundary

The current two tasks qualify as **real, reproducible, localized algorithmic
repair tasks**. They are useful for testing the evaluation pipeline, regression
preservation and source-bound evidence handling. They are not yet a validated
high-complexity benchmark or sufficient evidence of general Scheme-assisted
reasoning improvement.

This is a retrospective quality review on October 10, 2026, after observing the
pilot. The questions, source snapshots and graders were frozen before paid
execution; the more detailed review below was not a preregistered difficulty
assessment. It does not change the original questions, graders, outcomes or
token denominators. No new model calls were made for this review.

Quality is assessed separately for provenance, executable validity, interacting
reasoning obligations, grader strength, fairness, mechanism relevance and corpus
coverage. No arbitrary combined quality score is assigned. A task can satisfy
provenance and still have an inadequate oracle or weak relevance to our mechanism.

## Where the questions came from

These are questions restated from upstream defect reports, not tasks copied from
a paper benchmark. SWE-rebench and LiveCodeBench informed the collection and
evaluation protocol; they do not certify these two tasks' difficulty or quality.

| Task | Public source and first disclosure (UTC) | Parent revision | Fixed revision | Editable implementation |
| --- | --- | --- | --- | --- |
| Group centrality order | [NetworkX PR 8931](https://github.com/networkx/networkx/pull/8931), 2026-09-27 20:08:08 | `9f6079c0120416599ea5d4018bbaba229ea2e456` | `c1ebe046ec672eca7cba4dc88d6e0145406d693a` | `networkx/algorithms/centrality/group.py` |
| Series root precision | [SymPy issue 30698](https://github.com/sympy/sympy/issues/30698), 2026-10-08 05:24:57; [fix PR 30699](https://github.com/sympy/sympy/pull/30699) | `a0be64b90beabfaa8f76fcb31f2983b2476adfb4` | `8c02bd2b177bce1775cd3688cef07d225f69345d` | `sympy/polys/ring_series.py`, `sympy/polys/puiseux.py` |

Dates and identities are recorded in the [source audit](../../../.cache/ascent/archived-runs/docs/research/agent-inference/repository-evidence-source-audit.json).
Recent disclosure lowers reliance on old benchmark examples; it does not prove
that a dynamic model backend has never seen the source or solution. Exposure
remains unknown. The two root causes are distinct; the twelve trajectories are
repetitions and conditions on **two problems**, not twelve independent problems.

## Group centrality order: reasoning obligations and grader strength

The defect concerns a mathematical result that should be independent of the
ordering of an input group. The parent implementation updates path-betweenness
and shortest-path-count matrices in nested loops. Directed paths introduce
asymmetric dependencies; disconnected components and cycles make reachability
conditions matter. A repair must preserve numerical values as well as order
invariance. This assessment is grounded in the
[pinned parent implementation](https://github.com/networkx/networkx/blob/9f6079c0120416599ea5d4018bbaba229ea2e456/networkx/algorithms/centrality/group.py).

| Obligation | Why it requires reasoning | Current selected grader evidence | Remaining gap |
| --- | --- | --- | --- |
| Group permutation invariance | Mutation of shared matrices can make traversal order affect accumulated contributions | The four-member regression checks all 24 permutations; the forward/reverse regression also fails at the parent | Equality alone does not prove the shared answer is correct |
| Directed shortest-path accounting | Distance relations, path multiplicities and three path arrangements interact in the update | Directed ground-truth and directed weighted controls | No independent exhaustive shortest-path oracle over a generated graph corpus |
| Reachability and disconnected components | Matrix entries and endpoint subtraction depend on whether paths exist | Directed and undirected disconnected controls | No systematic cross-product of disconnectedness, weighting and order permutations |
| Endpoint and normalization behavior | Final subtraction and scaling must remain compatible with the path accounting | Endpoint, normalized and connected/disconnected controls | Existing fixtures cover selected combinations, not every supported combination |
| Established API behavior | Single groups, multiple groups and invalid members must remain compatible | Multiple-group, singleton, zero-value and invalid-node controls | Only the selected centrality class is graded; full repository behavior is not qualified |

The [pinned grading tests](https://github.com/networkx/networkx/blob/c1ebe046ec672eca7cba4dc88d6e0145406d693a/networkx/algorithms/centrality/tests/test_group.py)
yield **2 failure-to-pass test identities and 22 passing controls**. The fixed
implementation passes all 24. The smaller order regression already passes at
the parent and is counted as a control. The 24 permutations inside one test are
24 checks on one graph, not 24 independent graph problems.

**Difficulty assessment:** meaningful algorithmic interaction, but localized
diagnosis. The supplied question identifies the function and gives the failing
graph; only one implementation file is editable. A small change can fix this
defect. Neither the source size nor a model's long trajectory establishes high
difficulty. This is a useful focused invariant-repair task, not demonstrated
large-scale repository reasoning.

**Why it is useful for ASCENT:** observed reachability, path witnesses, matrix
update dependencies and failed invariants could become source-qualified facts
that later rounds reuse. Currently Scheme only derives local syntactic support;
it does not validate those numerical or update invariants. This task therefore
exposes a concrete missing semantic bridge, while the existing results measure
the narrower syntactic-support intervention.

## Series root precision: reasoning obligations and grader strength

The defect concerns how truncation precision is transferred through factoring,
root expansion and restoration of a leading power. These operations must agree
for reciprocal and positive roots, including fractional exponents. The quality
review checks the
[pinned parent implementation](https://github.com/sympy/sympy/blob/a0be64b90beabfaa8f76fcb31f2983b2476adfb4/sympy/polys/ring_series.py)
and [pinned grading tests](https://github.com/sympy/sympy/blob/8c02bd2b177bce1775cd3688cef07d225f69345d/sympy/polys/tests/test_ring_series.py).
The relation below is retrospective analysis, not an additional hint supplied
to the original model runs.

For `p = x**m * u`, taking the nth root restores a leading exponent `m/n`.
An internal term of exponent `e` is retained precisely when `e + m/n < P`, where
`P` is the requested final precision. This links the normalized expansion budget
to the exponent restored afterwards. Negative root orders change the direction
of the precision adjustment; rational exponents require exact arithmetic.

| Obligation | Why it requires reasoning | Current selected grader evidence | Remaining gap |
| --- | --- | --- | --- |
| Reciprocal consistency | A negative root order must preserve terms needed by inversion | The issue regression compares the reciprocal result with series inversion | One reported polynomial is not a generated reciprocal family |
| Truncation boundary | Terms strictly below precision survive; terms at the boundary do not | The square-root regression checks precision 2, 3 and 4 for the reported polynomial | No systematic grid of leading exponents, root orders and precision boundaries |
| Rational exponent handling | Factoring and restoration change exponent scales | Existing nth-root controls include fractional-power results | Finite fixtures, not a general algebraic oracle |
| Coefficient and domain behavior | Multivariate coefficients and symbolic constants must preserve ring behavior | Nth-root controls include multivariate and symbolic coefficients; inversion controls include domain exceptions | Only selected root/inversion tests are graded, not the whole symbolic system |

Qualification yields **2 failure-to-pass test identities and 1 passing control**;
the fixed implementation passes all three. These are test functions containing
multiple assertions, not merely three scalar examples. They also are not three
independent tasks. The model-visible development scope is only `test_inversion`;
the selected hidden root tests supply final acceptance.

**Difficulty assessment:** meaningful symbolic boundary reasoning, but still a
localized repair with a short mathematical relation. The question names the
function, supplies both failure examples and points to normalization and power
restoration. The editable scope is two files. There is no calibrated evidence
that this is a high-difficulty task for the backend used here.

**Why it is useful for ASCENT:** a checked precision relation, exact exponent
facts and reproducible boundary observations could prevent later rounds from
re-deriving the same constraint or repeating an invalid correction. Current
Scheme support does not encode or prove this algebra. A call-graph closure alone
cannot establish that an expansion has retained the required terms.

## Quality verdict by dimension

| Dimension | Current evidence | Verdict for this pilot |
| --- | --- | --- |
| Real provenance | Public defects, exact parent/fixed commits, dated source audit | Qualified |
| Executable defect | Parent fails semantic assertions; fixed passes the same selected grader | Qualified within the selected scope |
| Solution separation | Model tools expose parent snapshots; fixed code, diffs and hidden assertions are excluded | Implemented evaluation boundary; not a formal noninterference proof |
| Oracle independence | Grader execution and verdict are separate from model claims | Independent of model self-judgment; upstream tests are not an independently authored reference algorithm |
| Regression preservation | Failure-to-pass and pass-to-pass identities are both required | Useful finite controls; exhaustive correctness unproved |
| Complexity | Interacting graph-update or symbolic-boundary obligations | Meaningful local complexity; high difficulty uncalibrated |
| Framework fit | Opportunities for retained, invalidated, executable domain evidence | Partial: current intervention checks syntax, not domain claims |
| Coverage | Two repositories, two root causes, two repetitions per condition | Insufficient for broad task-family claims |
| Training novelty | Recent public disclosure | Exposure unknown |
| Causal interpretation | Same problem/tool contracts; fresh/retained expose identical support facts | Ordinary versus Scheme tests added support; persistence alone is not a designed thinking-enhancement intervention |

## Threats that must accompany the numerical results

1. **Small independent sample.** Increasing repeats improves observation of
   variability on these tasks but does not add independent root causes.
2. **Localized and guided search.** Named functions, concrete reproducers and
   narrow edit permissions reduce the search burden relative to general issue
   resolution. This is an experimental constraint, not evidence of broad ability.
3. **Grader blind spots.** Order equality can admit an equally wrong answer;
   finite symbolic fixtures can miss a boundary defect. Passing selected tests
   means selected-test acceptance, not complete semantic correctness.
4. **Tool friction.** Edit/search rejections and adapter constraints can consume
   calls and tokens. The ledger exposes these actions. Long runs alone cannot be
   used as a difficulty score or attributed entirely to reasoning.
5. **Unequal development coverage across tasks.** Graph controls expose a broad
   parent test class; symbolic development exposes only inversion. Conditions
   are matched within a task, but cross-task costs reflect different feedback.
6. **Mechanism mismatch.** Reusing syntactic dependency computation demonstrates
   checker reuse, but does not validate retained numerical/algebraic evidence as
   a cause of reduced thinking. Retained-history facts and component reuse must
   not be reported as proven semantic enhancement.
7. **Adaptive evaluation.** The uniform 40-turn continuation was introduced after
   all primary 10-turn trajectories were unfinished. It preserves every charge
   and continues every trajectory, but remains a separately labelled adaptive
   result rather than the original preregistered budget.

## Admission requirements for the next primary corpus

The following are proposed gates; they have **not** been executed or qualified
by this retrospective review. They must be completed before claiming stronger
task quality or starting a new confirmatory comparison.

- **Source dossier per task:** first disclosure, immutable parent/fixed revision,
  statement derivation, licence, environment, independence cluster and unknown
  exposure. Recent merge dates alone are insufficient.
- **Complexity dossier:** list interacting obligations and cross-function or
  cross-module paths with source evidence. Specify what the statement reveals
  and what the solver must discover. Separate algorithmic complexity from repair
  scope and tool-induced effort; do not require a long patch to qualify.
- **Stronger correctness checks:** for graph tasks, independently enumerate
  shortest paths on small supported graphs and test permutations, relabellings,
  direction, positive weights and disconnected cases. For series tasks, use
  independently derived exact expansions and precision-boundary families across
  root orders, leading exponents and supported coefficient domains. Mere
  agreement with the same fixed implementation is not an independent oracle.
- **Grader discrimination:** deliberately wrong candidate repairs must be
  rejected, including constant/equally-wrong outputs, fixture-specific answers
  and repairs that restore the reported case but violate passing controls.
  Record which obligation each grading family distinguishes.
- **Mechanism qualification:** specify the observable fact that enters Scheme,
  its checker, source/premise identity, invalidation rule and exact later-round
  feedback. Show that a checked domain claim actually reaches the model; cache
  reuse alone does not satisfy this gate. Match the observable feedback contract
  with Lean/Quint properties without certifying private reasoning text.
- **Independent holdout breadth:** complete the intended recursive graph,
  lifecycle/multiple-path, scoped-condition/negative-case and symbolic/numerical
  boundary families with independent root causes. Freeze evaluation membership
  before viewing its outcomes. Changes motivated by this pilot belong to
  development; measure them on fresh held-out tasks.
- **Difficulty calibration:** use a separate calibration split and a common tool
  interface to characterize difficulty and adapter friction. Do not select
  confirmatory tasks because Scheme already wins on them or retrospectively call
  expensive failures difficult. Retain calibration costs separately.

The current experiment remains a useful pilot with honest limits. Its strongest
contribution is a reproducible measurement path and concrete diagnosis of the
gap between syntactic evidence reuse and the domain evidence needed for the
intended reasoning enhancement.
