# Sibling-search Library diagnostic

Two finite fixtures and one stochastic trajectory per cell. Native reuse, model tool consumption, literal derivation counts and optimization quality are separate. Labels are lower bounds and same-model passes are correlated. Unused budget is not savings. Budget/call stops are censored and all failures remain.

| Source | Arm | Input + all output | Submitted / feasible / optimal branches | Mean normalized incumbent improvement | Stop |
|---|---|---:|---|---:|---|
| 0 | baseline | 10941 | 0 / 0 / 0 | 0.000 | failure Expecting value: line 1 column 1 (char 0) |
| 0 | facts | 14239 | 0 / 0 / 0 | 0.000 | budget_reservation  |
| 0 | scheme | 30311 | 1 / 1 / 1 | 0.167 | failure provider failure or incomplete |
| 1 | scheme | 30312 | 1 / 1 / 1 | 0.167 | failure provider failure or incomplete |
| 1 | facts | 30312 | 1 / 1 / 1 | 0.167 | failure provider failure or incomplete |
| 1 | baseline | 30577 | 1 / 1 / 1 | 0.167 | failure provider failure or incomplete |

| Source / arm / annotation pass | Cross-branch repetitions | Supplied premise rederived | Rejected labels | Failed annotation calls |
|---|---:|---:|---:|---:|
| 0 / baseline / 0 | 0 | 0 | 6 | 0 |
| 0 / baseline / 1 | 0 | 0 | 8 | 0 |
| 0 / facts / 0 | 0 | 0 | 13 | 0 |
| 0 / facts / 1 | 0 | 0 | 18 | 0 |
| 0 / scheme / 0 | 0 | 0 | 84 | 0 |
| 0 / scheme / 1 | 0 | 0 | 75 | 0 |
| 1 / scheme / 0 | 0 | 0 | 97 | 0 |
| 1 / scheme / 1 | 0 | 0 | 54 | 0 |
| 1 / facts / 0 | 0 | 0 | 107 | 0 |
| 1 / facts / 1 | 0 | 0 | 52 | 0 |
| 1 / baseline / 0 | 0 | 0 | 67 | 0 |
| 1 / baseline / 1 | 0 | 0 | 45 | 0 |

Solver known tokens: 146692; annotation known tokens: 321371. Unknown usage solver/annotation calls: 0 / 0.

All arms fork sibling histories from the same root and receive identical initial feasible incumbents and branch constraints. Evidence tools return current native Fact conclusions; Scheme adds named supports. The model chooses whether to invoke them. No anti-repetition instruction is supplied. The independent exhaustive grader is never given to the solver. A stale handle never becomes a verified tool conclusion.

The producer is a locally committed clean checkout. Native build, formal checks and source identities are explicit in plan/receipts; this does not qualify another machine or remote CI. raw.tar.gz retains every request, thinking, response, tool packet, failure and annotation.
