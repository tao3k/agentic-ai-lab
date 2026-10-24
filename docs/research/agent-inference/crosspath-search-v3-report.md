# Explicit branch search with a common feasible seed

Frozen plan `9872c7108ab0f0c246b6e0929b485974ddb3aebd8ca9fee0297dcca1c92ac890`. Disjoint three-call calibration passed: 9406 gross tokens. Six confirmatory phases, 83 solver calls. Scheme grader and annotation rules frozen before all calls.

A call chooses one previously unexplored child of a scheduled parent. Native raw-source checking admits the prefix; a deterministic common seed suffix creates an additional candidate. The starting solution is identical across arms for each goal, feasible, strictly non-optimal. A known-cost incomplete response is retained and charged, never admitted as an expansion; later bounded calls may progress. Unknown usage stops the phase. The controller preserves and returns the incumbent independently of model output completion.

Solver cost: 329175; separate annotation cost: 199807. Per-phase ceiling 65,536 input + all output tokens; output cap 3,072. Every unused token is reported as unused budget, never efficiency savings.

| Arm / goal | Calls / failed / truncated | Gross / unused | Seed → best value | Gap | Expansions / valid depth | Repeated / derived / reuse |
|---|---:|---:|---:|---:|---:|---:|
| baseline / 0 | 18 / 2 / 2 | 55978 / 9558 | 200 → 219 | 107 | 16 / 6 | 9 / 22 / 0 |
| baseline / 1 | 17 / 5 / 5 | 57753 / 7783 | 239 → 295 | 65 | 12 / 7 | 0 / 4 / 0 |
| fresh / 0 | 11 / 3 / 3 | 52368 / 13168 | 200 → 219 | 107 | 8 / 6 | 10 / 21 / 0 |
| fresh / 1 | 13 / 0 / 0 | 55321 / 10215 | 239 → 327 | 33 | 13 / 7 | 1 / 24 / 4 |
| retained / 0 | 13 / 2 / 2 | 54157 / 11379 | 200 → 219 | 107 | 11 / 6 | 0 / 16 / 7 |
| retained / 1 | 11 / 3 / 3 | 53598 / 11938 | 239 → 295 | 65 | 8 / 7 | 0 / 0 / 0 |

## Matched gross-token checkpoints

Best observed completed candidate before each boundary. A phase that never reaches a checkpoint is missing there; its under-budget endpoint is not substituted.

| Arm / goal | Gross checkpoint | Reached | Gain from seed | Expansions | Valid prefix depth |
|---|---:|---|---:|---:|---:|
| baseline / 0 | 16384 | True | 19 | 4 | 4 |
| baseline / 0 | 32768 | True | 19 | 10 | 6 |
| baseline / 0 | 49152 | True | 19 | 13 | 6 |
| baseline / 1 | 16384 | True | 49 | 5 | 5 |
| baseline / 1 | 32768 | True | 56 | 8 | 7 |
| baseline / 1 | 49152 | True | 56 | 12 | 7 |
| fresh / 0 | 16384 | True | 19 | 3 | 3 |
| fresh / 0 | 32768 | True | 19 | 6 | 6 |
| fresh / 0 | 49152 | True | 19 | 8 | 6 |
| fresh / 1 | 16384 | True | 46 | 4 | 4 |
| fresh / 1 | 32768 | True | 88 | 8 | 7 |
| fresh / 1 | 49152 | True | 88 | 11 | 7 |
| retained / 0 | 16384 | True | 19 | 2 | 2 |
| retained / 0 | 32768 | True | 19 | 6 | 6 |
| retained / 0 | 49152 | True | 19 | 9 | 6 |
| retained / 1 | 16384 | True | 0 | 1 | 1 |
| retained / 1 | 32768 | True | 49 | 4 | 4 |
| retained / 1 | 49152 | True | 56 | 7 | 7 |

All raw requests, returned reasoning, failed calls, invalid prefixes/completions, certificate store, exact span labels and native grades are retained in [the portable ledger](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v3-ledger.json) and [raw archive](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-search-v3-raw.tar.gz).

One fixed disjoint task, two goals, fixed order and stochastic model; descriptive pilot, no statistical causal claim.
Fresh and retained have identical model-visible packets/policy; only native state differs, so thinking differences cannot establish a cache-state cognitive effect.
Common seed is independently feasible and non-optimal; seed quality is not model search achievement. Controller selects incumbent, not a model submit.
Every input and all output, including failed output and prefix-cache input, count. Unused ceiling is unused budget, not savings. Checkpoints use only completed expansions before spend boundary.
Depth means native-admitted executed prefix length. Every seeded complete candidate has length seven by construction; full-plan length is not exploration depth.
Annotation extraction is same-provider, partially blinded, exact-span/native-truth validated; completeness and independent-rater agreement unvalidated. Absence of labels is not absence of repetition.
Each call resets reasoning history and receives frontier/incumbent plus immutable source; this is a controlled external-memory search scenario, not arbitrary long-context reasoning.
Prefix validity is legitimate selected-branch feedback; counterfactual child totals omit eligibility. No model gets the optimum or eligibility-pruned option list.

**Measurement warning:** zero accepted labels in a failed annotation row means missing measurement, not zero repetition. Whole-phase annotation failures are retained; use the bounded supplemental report and round summary for explicit measurement limitations.
