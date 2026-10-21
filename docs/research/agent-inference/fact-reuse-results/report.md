# Library Fact and proof-fragment reuse pilot

Two fixed tasks, one stochastic trajectory per arm/task. Scheme combines proof fragments and finite-absence partition; this does not isolate their individual effects. Repeat metrics are observed, exact-quote supported lower bounds; extraction completeness and inter-rater agreement are unvalidated. Unknown or rejected labels remain explicit. No hidden model reasoning is inferred. Full gxi unload remains an external runtime failure; the dynamic-module entry reloads and cleans the tested Library module against prelinked dependencies. Unused budget is censored, not savings.

| Task | Arm | Input + all output | Depth | Best value / optimum | Stop |
|---|---|---:|---:|---:|---|
| 0 | baseline | 9789 | 0 | 79 / 289 | failure incomplete_provider |
| 0 | facts | 9895 | 0 | 79 / 289 | failure incomplete_provider |
| 0 | scheme | 10386 | 0 | 79 / 289 | failure incomplete_provider |
| 1 | scheme | 10331 | 0 | 79 / 304 | failure incomplete_provider |
| 1 | facts | 9905 | 0 | 79 / 304 | failure incomplete_provider |
| 1 | baseline | 9785 | 0 | 79 / 304 | failure incomplete_provider |

Solver known cost: 60091 tokens; unknown-cost calls: 0. Independent annotation cost: 69991 tokens, recorded separately.

## Jointly reached input + all-output checkpoints

Thinking spans have no per-token progress timestamps. Since every response was incomplete and no action completed, repeat measurements at these checkpoints are unknown, not zero.

| Task / budget | Arm | Value | Depth | Observed repeated Facts / exact derivations | Missing / rejected labels |
|---|---|---:|---:|---:|---:|
| 0 / 8192 | baseline | 79 | 0 | unknown | unknown |
| 0 / 8192 | facts | 79 | 0 | unknown | unknown |
| 0 / 8192 | scheme | 79 | 0 | unknown | unknown |
| 1 / 8192 | scheme | 79 | 0 | unknown | unknown |
| 1 / 8192 | facts | 79 | 0 | unknown | unknown |
| 1 / 8192 | baseline | 79 | 0 | unknown | unknown |

A checkpoint excludes a model action that completes after the boundary. Unreached checkpoints are excluded from matched comparisons. Full outcomes, invalid branches, provider failures, forced cleanup, raw thinking, anchored labels and rejected annotations are retained. The unchanged ordinary search question contains no anti-repetition instructions.

**Measurement correction:** original annotation statistics are invalidated by an atomic ready-ID dispatch error. See [erratum](measurement-erratum.md) and corrected offline audit. The six truncated solver outcomes are unchanged.
