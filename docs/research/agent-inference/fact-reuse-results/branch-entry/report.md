# Sibling-search Library diagnostic

Two finite fixtures and one stochastic trajectory per cell. Native reuse, model tool consumption, literal derivation counts and optimization quality are separate. Literal chain counts have limited grammar recall; complete character partition does not certify semantic completeness. Unresolved lines are retained. Thinking truncated at a checkpoint remains censored even if finalization returns an answer. Unused budget is not savings. Budget/call stops are censored and all failures remain.

| Source | Arm | Input + all output | Submitted / feasible / optimal branches | Mean normalized incumbent improvement | Stop |
|---|---|---:|---|---:|---|
| 0 | baseline | 26581 | 4 / 1 / 0 | 0.158 | budget_reservation  |
| 0 | facts | 25188 | 3 / 2 / 1 | 0.325 | budget_reservation  |
| 0 | scheme | 23948 | 2 / 1 / 1 | 0.167 | budget_reservation  |
| 1 | scheme | 23972 | 2 / 2 / 0 | 0.115 | budget_reservation  |
| 1 | facts | 25224 | 3 / 3 / 1 | 0.325 | budget_reservation  |
| 1 | baseline | 26584 | 4 / 2 / 0 | 0.142 | budget_reservation  |

| Source / arm / annotation pass | Cross-branch repetitions | Supplied premise rederived | Rejected labels | Failed annotation calls |
|---|---:|---:|---:|---:|
| 0 / baseline / 0 | 61 | 0 | 0 | 0 |
| 0 / facts / 0 | 0 | 0 | 0 | 0 |
| 0 / scheme / 0 | 0 | 0 | 0 | 0 |
| 1 / scheme / 0 | 0 | 0 | 0 | 0 |
| 1 / facts / 0 | 0 | 0 | 0 | 0 |
| 1 / baseline / 0 | 75 | 0 | 0 | 0 |

Solver known tokens: 151497; annotation known tokens: 0. Unknown usage solver/annotation calls: 0 / 0.

All arms fork sibling histories from the same root and receive identical initial feasible incumbents and branch constraints. At each branch entry, Fact receives native conclusions and Scheme receives the same conclusions plus named supports from the same public Python binding. Baseline has neither. Only the common submission tool is exposed; no anti-repetition instruction is supplied. A bounded non-thinking finalization can return an answer after truncated thinking, but does not certify complete reasoning. The independent exhaustive grader is never given to the solver. A stale handle never becomes a verified tool conclusion.

The producer is a locally committed clean checkout. Native build, formal checks and source identities are explicit in plan/receipts; this does not qualify another machine or remote CI. raw.tar.gz retains every request, thinking, response, tool packet, failure and annotation.
