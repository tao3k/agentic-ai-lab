# Cross-path Fact and derivation reuse: completed next round

The experiment now includes an initial-evidence-free baseline, matched fresh/retained packets, direct source-anchored reasoning annotations, frozen independent native grading, and gross input + all output/thinking accounting. It has not demonstrated a quality/depth improvement.

## Outcome

Eighteen phases completed: 12 instrumentation phases plus six disjoint-task phases after removing eligibility-oracle feedback. Three valid submissions and 15 output-censored failures. No candidate reached the independent optimum. All raw requests, responses, SSE, reasoning text, certificates, incomplete attempts and grades are retained.

| Oracle-free replay arm | Valid submissions | Gross solver tokens | Explicit derivation episodes extracted | Valid full candidates | Executed prefixes | Best gaps |
|---|---:|---:|---:|---:|---:|---|
| baseline | 0/2 | 32606 | 30 | 1 | 2 | [None, 47] |
| fresh | 0/2 | 24012 | 21 | 0 | 0 | [None, None] |
| retained | 0/2 | 24012 | 28 | 0 | 0 | [None, None] |

The ceiling was 65,536 gross tokens per phase, but every oracle-free phase hit the common 8,192-output per-call cap before successful completion. Unspent ceiling is not evidence of efficiency; token totals cannot be compared as equally completed workloads. Only baseline goal 1 produced an independently valid candidate (gap 47), without successful submit.

## Direct thinking evidence

Frozen automatic extraction found ten cross-goal matches (fresh seven, retained three) with matching source/claim/premise keys. A post-outcome qualitative span audit distinguishes six complete two-path reconstructions, one partial-chain replay, one conjunction-only restatement, and two core replays that also add an alternative witness. The automatic within-phase strict prior-link counter is zero; extraction completeness is not established. Do not interpret that counter as absence of redundant thought.

A fresh-arm F0 example, from external returned reasoning (same source and proof support in both goals):

> Goal 0: - 0->7: 0->2->4->7 yes. 1->9: 1->2->4->7->9 yes. F0 eligible.

> Goal 1: F0: (0,7) and (1,9). 0->7: 0->2->4->7 yes. 1->9: 1->2->4->7->9 yes. F0 eligible.

Both initial packets already contained admitted F0 and its derivation nodes. This is direct evidence of explicit source-bound proof reconstruction after a goal reset. It does not quantify latent cognitive effort, nor show that native retention caused a model improvement: fresh and retained had identical model-visible packets.

## Design and evidence boundaries

- Seven ordered choice stages share eligibility fragments, each requiring two graph paths. Each positive fragment is used across several stages/alternative choices; values, pair bonuses and two resource limits make the search nontrivial. The disjoint replay has 3,587 / 2,838 feasible full plans.
- In v1, inspect leaked eligibility-pruned next choices. V2 removes that output and per-option failure IDs, clarifies common needs-row columns and option/fragment identity, and uses disjoint fixed seed 110317. Those common instrumentation changes are frozen before any v2 model outcome. Do not pool v1/v2 as a single causal estimate.
- The grader performs raw-edge traversal and exhaustive constrained enumeration without ASCENT proofs or model reasoning. The native executable SHA256 is identical in both protocols; ten small exhaustive/pruned comparisons, hand arithmetic/resource cases and cycle/absence checks qualify its finite scope.
- Baseline has no initial packet; the same native fragment tool remains available to every arm. Fresh/retained packets and raw task/control bytes match. Gross accounting includes prefix-cache input in full, all repeated history and output/thinking. Actual usage is authoritative; unknown use or reservation violations fail-stop.
- Annotation uses a separate same-provider non-thinking call with arm/grade metadata withheld. Content can reveal evidence availability. Exact Unicode character ranges, quotes, source hashes, prior links, uncertainty and rejected labels are kept; native claim truth does not establish semantic-label completeness or inter-rater agreement.
- Source binding covers current candidate source bytes plus a qualified inherited production kernel/dependency snapshot and newly compiled native bridge. It is not whole-checkout build/CI qualification or real-world evidence authority.
- Native retained proof construction is one vs fresh two in v2. Model solver failures and quality do not improve. There is no end-to-end speed claim.

## Cost and retained artifacts

34 real solver calls charged 323,336 gross tokens; 18 measurement calls charged 218,906; study total 542,242. Measurements are separate overhead, not credited to solver budget. Both binding/input/budget audits passed with known usage and no overshoot.

Source HEAD: `652934cd728d7edee32df020af75e9632dffc755`. Plans: `2e5464ae5c1230e3ce210217b405bb61c02d9c17ce548b0d227fe0c0b79b079a` and `1150d2e7ff106b48b6f16fc2b89c0c951c8f8caaba796e43ef91269aee9f40db`.

- [Oracle-free replay report](crosspath-search-v2-report.md) and [portable ledger](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v2-ledger.json).
- [Direct span audit and paired quotes](crosspath-thinking-span-review.md); [all replay labels](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-v2-thinking-annotations.md).
- [Original instrumentation report](crosspath-search-report.md) and [all original labels](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-thinking-annotations.md).
- [Original raw archive](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-raw.tar.gz), [replay raw archive](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v2-raw.tar.gz).
- [Original integrity receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-integrity.json), [replay integrity receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v2-integrity.json).

Twelve focused Python tests passed, including the no-eligibility-oracle projection and span/prior rejection guards. Native qualification and post-run source/artifact verification passed. The next discriminating experiment should protect a common non-optimal feasible starting plan and bound each branch-expansion decision, so output censoring does not erase candidate coverage; preregister that protocol before any new model outcome.
