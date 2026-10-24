# Sibling-search Library diagnostic

Two finite fixtures and one stochastic trajectory per cell. Native reuse, model tool consumption, literal derivation counts and optimization quality are separate. Literal chain counts have limited grammar recall; complete character partition does not certify semantic completeness. Unresolved lines are retained. Thinking truncated at a checkpoint remains censored even if finalization returns an answer. Unused budget is not savings. Budget/call stops are censored and all failures remain.

| Source | Arm | Input + all output | Submitted / feasible / optimal branches | Mean normalized incumbent improvement | Stop |
|---|---|---:|---|---:|---|
| 0 | baseline | 32313 | 2 / 1 / 1 | 0.167 | failure thinking incomplete under total budget; no nonthinking salvage |
| 0 | facts | 32313 | 2 / 2 / 2 | 0.333 | failure thinking incomplete under total budget; no nonthinking salvage |
| 0 | scheme | 32313 | 2 / 2 / 2 | 0.333 | failure thinking incomplete under total budget; no nonthinking salvage |
| 1 | scheme | 32310 | 2 / 2 / 2 | 0.333 | failure thinking incomplete under total budget; no nonthinking salvage |
| 1 | facts | 29708 | 3 / 3 / 3 | 0.500 | budget_reservation  |
| 1 | baseline | 32311 | 1 / 0 / 0 | 0.000 | failure thinking incomplete under total budget; no nonthinking salvage |

| Source / arm / annotation pass | Cross-branch repetitions | Supplied premise rederived | Rejected labels | Failed annotation calls |
|---|---:|---:|---:|---:|
| 0 / baseline / 0 | 26 | 0 | 0 | 0 |
| 0 / facts / 0 | 0 | 0 | 0 | 0 |
| 0 / scheme / 0 | 0 | 0 | 0 | 0 |
| 1 / scheme / 0 | 0 | 0 | 0 | 0 |
| 1 / facts / 0 | 0 | 4 | 0 | 0 |
| 1 / baseline / 0 | 35 | 0 | 0 | 0 |

Solver known tokens: 191268; annotation known tokens: 0. Unknown usage solver/annotation calls: 0 / 0.

All arms fork sibling histories from the same root and receive identical initial feasible incumbents and branch constraints. At each branch entry, Fact receives native conclusions and Scheme receives the same conclusions plus named supports from the same public Python binding. Baseline has neither. Only the common submission tool is exposed; no anti-repetition instruction is supplied. Incomplete thinking is retained as a censored failure and is never salvaged by non-thinking finalization. Only completed plain responses may use structured finalization within the same total budget. The independent exhaustive grader is never given to the solver. A stale handle never becomes a verified tool conclusion.

The producer is a locally committed clean checkout. Native build, formal checks and source identities are explicit in plan/receipts; this does not qualify another machine or remote CI. raw.tar.gz retains every request, thinking, response, tool packet, failure and annotation.

Editorial correction: the generated original remains in raw.tar.gz. Solver data and report.json are unchanged.
