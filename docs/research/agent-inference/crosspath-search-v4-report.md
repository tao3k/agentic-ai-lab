# Explicit branch search with a common feasible seed

Frozen plan `731fcda802ad891ae054830a32712e932e6b55e746418f2cd785755fd9708528`. Disjoint three-call calibration passed: 7013 gross tokens. Six confirmatory phases, 77 solver calls. Scheme grader and annotation rules frozen before all calls.

A call chooses one previously unexplored child of a scheduled parent. Native raw-source checking admits the prefix; a deterministic common seed suffix creates an additional candidate. The starting solution is identical across arms for each goal, feasible, strictly non-optimal. A known-cost incomplete response is retained and charged, never admitted as an expansion; later bounded calls may progress. Unknown usage stops the phase. The controller preserves and returns the incumbent independently of model output completion.

Solver cost: 294736; separate annotation cost: 183071. Per-phase ceiling 65,536 input + all output tokens; output cap 8,192. Every unused token is reported as unused budget, never efficiency savings.

| Arm / goal | Calls / failed / truncated | Gross / unused | Seed → best value | Gap | Expansions / valid depth | Repeated / derived / reuse |
|---|---:|---:|---:|---:|---:|---:|
| baseline / 0 | 18 / 0 / 0 | 49557 / 15979 | 224 → 303 | 52 | 18 / 7 | 0 / 0 / 0 |
| baseline / 1 | 18 / 0 / 0 | 51281 / 14255 | 244 → 334 | 21 | 18 / 7 | 0 / 0 / 0 |
| fresh / 0 | 10 / 0 / 0 | 47428 / 18108 | 224 → 284 | 71 | 10 / 7 | 0 / 0 / 0 |
| fresh / 1 | 11 / 0 / 0 | 48020 / 17516 | 244 → 349 | 6 | 11 / 7 | 8 / 18 / 1 |
| retained / 0 | 11 / 0 / 0 | 47525 / 18011 | 224 → 295 | 60 | 11 / 7 | 0 / 0 / 0 |
| retained / 1 | 9 / 0 / 0 | 50925 / 14611 | 244 → 349 | 6 | 9 / 7 | 0 / 0 / 0 |

## Matched gross-token checkpoints

Best observed completed candidate before each boundary. A phase that never reaches a checkpoint is missing there; its under-budget endpoint is not substituted.

| Arm / goal | Gross checkpoint | Reached | Gain from seed | Expansions | Valid prefix depth |
|---|---:|---|---:|---:|---:|
| baseline / 0 | 16384 | True | 42 | 5 | 4 |
| baseline / 0 | 32768 | True | 79 | 11 | 7 |
| baseline / 0 | 49152 | True | 79 | 17 | 7 |
| baseline / 1 | 16384 | True | 77 | 5 | 5 |
| baseline / 1 | 32768 | True | 90 | 11 | 7 |
| baseline / 1 | 49152 | True | 90 | 16 | 7 |
| fresh / 0 | 16384 | True | 42 | 3 | 3 |
| fresh / 0 | 32768 | True | 60 | 6 | 6 |
| fresh / 0 | 49152 | False | None | None | None |
| fresh / 1 | 16384 | True | 80 | 3 | 3 |
| fresh / 1 | 32768 | True | 105 | 7 | 7 |
| fresh / 1 | 49152 | False | None | None | None |
| retained / 0 | 16384 | True | 18 | 3 | 3 |
| retained / 0 | 32768 | True | 71 | 6 | 6 |
| retained / 0 | 49152 | False | None | None | None |
| retained / 1 | 16384 | True | 80 | 3 | 3 |
| retained / 1 | 32768 | True | 105 | 6 | 6 |
| retained / 1 | 49152 | True | 105 | 8 | 7 |

All raw requests, returned reasoning, failed calls, invalid prefixes/completions, certificate store, exact span labels and native grades are retained in [the portable ledger](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v4-ledger.json) and [raw archive](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v4-raw.tar.gz).

One fixed disjoint task, two goals, fixed order and stochastic model; descriptive pilot, no statistical causal claim.
Fresh and retained have identical model-visible packets/policy; only native state differs, so thinking differences cannot establish a cache-state cognitive effect.
Common seed is independently feasible and non-optimal; seed quality is not model search achievement. Controller selects incumbent, not a model submit.
Every input and all output, including failed output and prefix-cache input, count. Unused ceiling is unused budget, not savings. Checkpoints use only completed expansions before spend boundary.
Depth means native-admitted executed prefix length. Every seeded complete candidate has length seven by construction; full-plan length is not exploration depth.
Annotation extraction is same-provider, partially blinded, exact-span/native-truth validated; completeness and independent-rater agreement unvalidated. Absence of labels is not absence of repetition.
Each call resets reasoning history and receives frontier/incumbent plus immutable source; this is a controlled external-memory search scenario, not arbitrary long-context reasoning.
Prefix validity is legitimate selected-branch feedback; counterfactual child totals omit eligibility. No model gets the optimum or eligibility-pruned option list.

**Measurement warning:** zero accepted labels in a failed annotation row means missing measurement, not zero repetition. Whole-phase annotation failures are retained; use the bounded supplemental report and round summary for explicit measurement limitations.
