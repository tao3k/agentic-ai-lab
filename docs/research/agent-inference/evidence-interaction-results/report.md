# Native Fact interaction study

Frozen plan `4fb3007edebca0429923ac4d58cdf72d8c67c0d81040d32a84fc38cf808ef111`. One implementation; three configured treatments. No solver instructions or anti-repetition prompt.

| Task / arm | Gross / unused | Seed → best | Gap | Calls / failures / truncation | Native Fact prunings |
|---|---:|---:|---:|---:|---:|
| 0 / baseline | 40982 / 24554 | 78 → 189 | 114 | 5 / 3 / 3 | 0 |
| 0 / facts | 46022 / 19514 | 78 → 189 | 114 | 5 / 3 / 3 | 0 |
| 0 / prune | 49085 / 16451 | 78 → 189 | 114 | 5 / 3 / 3 | 3 |
| 1 / prune | 48582 / 16954 | 134 → 220 | 92 | 5 / 3 / 3 | 1 |
| 1 / facts | 50022 / 15514 | 134 → 220 | 92 | 5 / 3 / 3 | 0 |
| 1 / baseline | 52245 / 13291 | 134 → 220 | 92 | 6 / 4 / 4 | 0 |

## Matched input + all-output checkpoints

| Task / arm | Gross checkpoint / reached | Value | Expansions / admitted depth | Qualified positive repeats / derives / reuse | Missing measurements |
|---|---:|---:|---:|---:|---:|
| 0 / baseline | 16384 / True | 189 | 2 / 2 | 0 / 2 / 0 | 0 |
| 0 / baseline | 32768 / True | 189 | 2 / 2 | 0 / 2 / 0 | 0 |
| 0 / facts | 16384 / True | 189 | 2 / 2 | 0 / 0 / 0 | 0 |
| 0 / facts | 32768 / True | 189 | 2 / 2 | 0 / 0 / 0 | 0 |
| 0 / prune | 16384 / True | 189 | 2 / 2 | 0 / 0 / 0 | 0 |
| 0 / prune | 32768 / True | 189 | 2 / 2 | 0 / 0 / 0 | 0 |
| 1 / prune | 16384 / True | 134 | 0 / 0 | 0 / 0 / 0 | 0 |
| 1 / prune | 32768 / True | 190 | 1 / 1 | 0 / 0 / 0 | 0 |
| 1 / facts | 16384 / True | 134 | 0 / 0 | 0 / 0 / 0 | 0 |
| 1 / facts | 32768 / True | 190 | 1 / 1 | 0 / 0 / 0 | 0 |
| 1 / baseline | 16384 / True | 134 | 0 / 0 | 0 / 0 / 0 | 0 |
| 1 / baseline | 32768 / True | 220 | 2 / 2 | 0 / 0 / 0 | 0 |

Solver gross tokens 286938; separate calibration 12900; separate measurement 260190.

Two deterministic tasks, one stochastic run per arm; descriptive study, not a causal/statistical effect estimate.
All arms retain Scheme execution and post-choice checking. Baseline omits model-visible Fact evidence and Fact prepruning.
Task/action contracts are common; there are no solver system instructions, anti-repetition directives or requested audit narration.
Only actual completed native-admitted prefixes measure depth; full seed-suffix candidates do not establish explored depth.
Unused ceiling is not savings. Matched checkpoints credit only observed completed calls before the common gross-token boundary.
Positive repeated labels require exact quotes, literal IDs/endpoints, independently true atoms and native-qualified explicit edge-chain/conjunction support. This narrow metric omits unsupported/negative/ambiguous derivations.
Same-provider extraction is partially blind but not independently validated for completeness or semantic category accuracy. Counts are qualified labels, not cognitive ground truth.
This is a Library consumer test, not a Library Search/Fact workflow API or MRR integration. Agentic AI Lab revision projection and reevaluation planning are exercised before model calls at fixed cuts; live revision during the model dialogue remains unqualified.
Retained Session publication is checked against independently replayed finite evidence. Proof replay costs are additional; no cross-generation retained-proof algorithm or source authentication is claimed.
Native proof builds/hits are not end-to-end speed or model-thinking savings. Negative and failed outcomes remain in all records.
