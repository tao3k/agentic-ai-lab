# Library Fact and proof-fragment reuse pilot

Two unchanged fixed tasks, one stochastic trajectory per arm/task. Scheme combines proof fragments and finite-absence partition; this does not isolate their individual effects. All arms replay their own prior thinking and paired tool outputs, charging all repeated input. Repeat metrics are observed, exact-quote supported lower bounds; extraction completeness and inter-rater agreement are unvalidated. At checkpoints inside a model call, repeat counts are unknown because per-token usage timing is unavailable. Unknown or rejected labels remain explicit. No hidden model reasoning is inferred. Current captured native and full gxi qualification passes; prior dyld cleanup failures remain retained and no global runtime fix is claimed. Unused budget is censored, not savings.

| Task | Arm | Input + all output | Depth | Best value / optimum | Stop |
|---|---|---:|---:|---:|---|
| 0 | baseline | 53455 | 1 | 79 / 289 | failure Expecting value: line 1 column 1 (char 0) |
| 0 | facts | 12521 | 0 | 79 / 289 | failure Expecting value: line 1 column 1 (char 0) |
| 0 | scheme | 49724 | 1 | 79 / 289 | failure Expecting value: line 1 column 1 (char 0) |
| 1 | scheme | 45040 | 2 | 79 / 304 | budget_reservation  |
| 1 | facts | 32040 | 1 | 79 / 304 | failure Expecting value: line 1 column 1 (char 0) |
| 1 | baseline | 18043 | 0 | 79 / 304 | failure Expecting value: line 1 column 1 (char 0) |

Solver known cost: 210823 tokens; unknown-cost calls: 0. Independent annotation cost: 139315 tokens, recorded separately.

## Jointly reached input + all-output checkpoints

| Task / budget | Arm | Value | Depth | Observed repeated Facts / exact derivations | Missing / rejected labels |
|---|---|---:|---:|---:|---:|
| 0 / 8192 | baseline | 79 | 0 | None / None | 0 / 0 |
| 0 / 8192 | facts | 79 | 0 | None / None | 0 / 0 |
| 0 / 8192 | scheme | 79 | 0 | None / None | 0 / 0 |
| 1 / 8192 | scheme | 79 | 0 | None / None | 0 / 0 |
| 1 / 8192 | facts | 79 | 0 | None / None | 0 / 0 |
| 1 / 8192 | baseline | 79 | 0 | None / None | 0 / 0 |
| 1 / 16384 | scheme | 79 | 0 | None / None | 0 / 0 |
| 1 / 16384 | facts | 79 | 1 | None / None | 0 / 16 |
| 1 / 16384 | baseline | 79 | 0 | None / None | 0 / 0 |

A checkpoint excludes a model action that completes after the boundary. Unreached checkpoints are excluded from matched comparisons. Full outcomes, invalid branches, provider failures, forced cleanup, raw thinking, anchored labels and rejected annotations are retained. The unchanged ordinary search question contains no anti-repetition instructions.
