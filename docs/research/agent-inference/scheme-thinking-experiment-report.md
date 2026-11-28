<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->
<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->
# Scheme Evidence and Complex Model Thinking: Full Experimental Report

Date: 2026-10-10. Requested provider model: `deepseek-flash`; thinking effort: `high`.

## Executive results

The corrected tool-history experiment completed **16 trajectories** on **4 distinct complex questions**, two trials per condition. Control verified **7/8**, Scheme verified **8/8**. Cumulative thinking through the first verified answer (or censoring) was **560,342 vs 199,765 tokens**. The weighted reduction on jointly verified pairs was **60.92%** across **7/8 pairs**. Failed query construction and repairs are charged, not discarded.

This delivery includes 43 original-protocol calls, 54 corrected-protocol calls, and 5 original-protocol adaptive recovery calls and 2 complete-history continuation calls: **104 accepted provider calls** in total. The 17 rejected transport requests have unknown usage and are reported separately. There are 4 distinct questions, not that many independent tasks; repeated condition/trial runs and repairs do not increase question diversity.

## What changed and why

The original JSON-action protocol retained external actions and Scheme receipts, but did not forward previous provider reasoning items and did not supply a tools parameter. It therefore tested external evidence assistance without actual provider thinking-state continuation. The corrected protocol forwards the complete prior reasoning, assistant messages, function calls and paired function results in both arms. The additional Scheme evidence tool is the treatment. Previous provider reasoning is forwarded opaquely; Scheme validates expressed derivations, not private thoughts. [Official thinking-mode behavior](https://api-docs.deepseek.com/guides/thinking_mode/).

The corrected phase also changes action representation and raises the equal per-call ceiling from 65,536 to 131,072. It reuses the four questions after diagnosis, so it is a development follow-up, not a new independent holdout. Between-phase changes cannot identify a single-factor effect. Within each phase the question, facts, verifier, model, effort, ceiling and turn policy are matched across arms.

The provider rejected `tool_choice=required` in thinking mode. After preserving 16 failed scheduled requests and one diagnostic rejection, the corrected experiment used supported automatic tool choice. Bounded scheduling now permits two workers and stops dispatch on transport failure. The frozen final run is complete; no outcomes were replaced.

## Corrected tool-history experiment

## Research objective

Measure whether source-bound Scheme evidence reduces cumulative model thinking to the first independently verified correct answer on four compound questions. The model reasons about each complete question; Scheme checks externally expressed derivations and retains evidence for later reasoning. Subproblem-first planning is not required.

## Experiment plan and boundaries

Four frozen synthetic questions, two trials per condition, 16 trajectories, at most 8 turns per trajectory. Both conditions can scan the same raw facts. Each source contains 96 Actors, 32 Films, 8 Directors, 4 Countries and 391 facts. Entity IDs are opaque. Trials start fresh; these are repeated cold trials, not free warm-cache trials.

Control reasons over raw facts. Assistance additionally has executable claim checking, evidence publication and source-bound alias reuse. No mandatory first-round query or evidence-use gate for a correct answer. Private gold programs, values and counts are excluded from requests. Verification returns only verified/not_verified. Incorrect actions and answers consume turns; no automatic paid retry or post-hoc primary-score replacement.

Requested model: deepseek-flash; reasoning effort: high; output ceiling: 131,072 per call. Frozen plan SHA-256: `d89ad9716e76298cf03b0fd410aa5eb8dd7f92e1955068e185c61c47fc173ac4`. Runtime artifact SHA-256: `c2acb2751350f5590ca0a0dbb25aa9cb43d35b4b0716b11f2327802030ec5420`.

## Complete questions

### four-hop-shared-witness

Return actor x iff there is a directed mentor walk of EXACTLY FOUR edges x->p->q->r->z, and z and an actor t in target appear in the SAME film f whose director has at least one selected_country. That supporting film f must not be banned_film. In addition, x must have NO appearance in ANY banned film. Intermediate actors may repeat; x need not act in f. Nationality belongs to the director, not the actors. All joins in this witness must use the same f, director and t. Use only the supplied finite relations. Return unique actor identifiers.

### recursive-clean-bridge

Return actor x iff x reaches an actor z through ONE OR MORE directed mentor edges, and z and a target actor t appear in the SAME film f whose director has a selected_country; f must not be banned. Neither x nor z may appear in ANY banned film. Paths may traverse banned-film actors in intermediate positions: the actor-wide exclusion applies ONLY to x and z. Cycles are allowed; a zero-edge identity path is not sufficient. Use only the supplied finite relations. Return unique actor identifiers.

### scoped-union-recursive-branch

Return the UNION of two branches. LEFT: x has an EXACTLY FOUR-edge directed mentor walk to z, where z and a target actor share a film f with a selected-country director; f is not banned, and x has NO appearance in ANY banned film. RIGHT: x has a ONE-OR-MORE-edge directed mentor path to a target actor, and x acts in some film g with a selected-country director, where this supporting g is not banned. The right branch has NO actor-wide banned-film exclusion: a different banned appearance must not remove x from RIGHT. The two branches may have different witnesses. Preserve local and branch exclusion scope before taking the union. Use only the supplied finite relations. Return unique actor identifiers.

### all-targets-positive-reach

Return actors x in actor_domain that can reach EVERY actor t in target through ONE OR MORE directed mentor edges, and that share at least one unbanned film f with a target actor, where the director of that same f has a selected_country. This is universal coverage over the entire target relation, NOT existence of one reachable target. x must have NO appearance in ANY banned film. A target actor requires a positive-length path to itself; identity alone does not count. Cycles count as positive paths. For an empty target set the reachability condition is vacuous, but the coappearance condition still requires a target witness. Use only the supplied finite relations. Return unique actor identifiers.

## Accuracy and total consumed work

| Condition | Verified / trajectories | Accuracy | First submitted answer correct / assigned | Model calls | Thinking tokens | Input tokens | Output incl. thinking | Scheme/local action seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| raw-fact-reasoning | 7/8 | 87.5% | 5/8 | 21 | 560,342 | 488,363 | 565,577 | 0.0509 |
| scheme-evidence | 8/8 | 100.0% | 8/8 | 33 | 199,765 | 533,167 | 216,924 | 2.6211 |

All consumed work includes unsuccessful trajectories. Usage completeness is recorded in the audit. Thinking tokens are a subset of output tokens, not an extra billable amount. Local action time includes scans, oracle grading and failed action handling as well as Scheme queries; it is not pure engine compute time. Runtime initialization and pre-turn store admission are outside that timer.

## First-correct trajectories

| Question | Trial | Condition | Verified | Calls through first correct / censoring | Thinking tokens | Observable actions |
|---|---:|---|---|---:|---:|---|
| all-targets-positive-reach-seed-20261313 | 1 | raw-fact-reasoning | Yes | 2 | 33,367 | scan → answer |
| all-targets-positive-reach-seed-20261313 | 1 | scheme-evidence | Yes | 4 | 18,178 | scan → query → query → answer |
| all-targets-positive-reach-seed-20261313 | 2 | raw-fact-reasoning | Yes | 2 | 57,275 | scan → answer |
| all-targets-positive-reach-seed-20261313 | 2 | scheme-evidence | Yes | 3 | 19,875 | scan → query → answer |
| four-hop-shared-witness-seed-20261010 | 1 | raw-fact-reasoning | Yes | 6 | 108,968 | scan → answer → answer → answer → answer → answer |
| four-hop-shared-witness-seed-20261010 | 1 | scheme-evidence | Yes | 4 | 24,181 | scan → invalid action shape → query → answer |
| four-hop-shared-witness-seed-20261010 | 2 | raw-fact-reasoning | Yes | 3 | 84,303 | scan → answer → answer |
| four-hop-shared-witness-seed-20261010 | 2 | scheme-evidence | Yes | 4 | 17,254 | scan → invalid action shape → query → answer |
| recursive-clean-bridge-seed-20261111 | 1 | raw-fact-reasoning | Yes | 2 | 27,030 | scan → answer |
| recursive-clean-bridge-seed-20261111 | 1 | scheme-evidence | Yes | 3 | 33,125 | scan → query → answer |
| recursive-clean-bridge-seed-20261111 | 2 | raw-fact-reasoning | Yes | 2 | 56,147 | scan → answer |
| recursive-clean-bridge-seed-20261111 | 2 | scheme-evidence | Yes | 3 | 30,394 | scan → query → answer |
| scoped-union-recursive-branch-seed-20261212 | 1 | raw-fact-reasoning | Yes | 2 | 61,890 | scan → answer |
| scoped-union-recursive-branch-seed-20261212 | 1 | scheme-evidence | Yes | 7 | 24,657 | scan → invalid action shape → query → query → query → query → answer |
| scoped-union-recursive-branch-seed-20261212 | 2 | raw-fact-reasoning | No: censored | 2 | 131,362 | scan → invalid action shape |
| scoped-union-recursive-branch-seed-20261212 | 2 | scheme-evidence | Yes | 5 | 32,101 | scan → invalid action shape → query → query → answer |

## Results by question family

| Family | Control verified | Scheme verified | Control thinking | Scheme thinking | Reduction on jointly verified trials |
|---|---:|---:|---:|---:|---:|
| four-hop-shared-witness | 2/2 | 2/2 | 193,271 | 41,435 | 78.56% (2 pairs) |
| recursive-clean-bridge | 2/2 | 2/2 | 83,177 | 63,519 | 23.63% (2 pairs) |
| scoped-union-recursive-branch | 1/2 | 2/2 | 193,252 | 56,758 | 60.16% (1 pairs) |
| all-targets-positive-reach | 2/2 | 2/2 | 90,642 | 38,053 | 58.02% (2 pairs) |

## Matched thinking reductions

| Question | Trial | Both verified | Thinking reduction | Turn reduction |
|---|---:|---|---:|---:|
| four-hop-shared-witness-seed-20261010 | 1 | Yes | 77.81% | 33.33% |
| four-hop-shared-witness-seed-20261010 | 2 | Yes | 79.53% | -33.33% |
| recursive-clean-bridge-seed-20261111 | 1 | Yes | -22.55% | -50.00% |
| recursive-clean-bridge-seed-20261111 | 2 | Yes | 45.87% | -50.00% |
| scoped-union-recursive-branch-seed-20261212 | 1 | Yes | 60.16% | -250.00% |
| scoped-union-recursive-branch-seed-20261212 | 2 | No | Undefined (unverified pair) | Undefined (unverified pair) |
| all-targets-positive-reach-seed-20261313 | 1 | Yes | 45.52% | -100.00% |
| all-targets-positive-reach-seed-20261313 | 2 | Yes | 65.30% | -50.00% |

Jointly verified pairs: **7/8**. Measurable thinking pairs: 7. Weighted cumulative thinking reduction on that measurable subset: **60.92%**. Positive means less thinking; negative means more. Read this subset together with full-condition accuracy and censored consumed costs; it does not erase failed trajectories.

## Failure and repair costs

| Condition | Failed attempts | Failure + repair calls | Failure + repair thinking | Peak-price estimate USD |
|---|---:|---:|---:|---:|
| raw-fact-reasoning | 6 | 8 | 323,755 | 0.400001 |
| scheme-evidence | 4 | 16 | 96,552 | 0.147668 |

Failure + repair includes the first failed attempt and every later call until verification or censoring. It is a measured suffix cost, not proof that every token was avoidable. Ordinary successful evidence-building before a failure remains charged in the trajectory total. Adaptive follow-up costs, when present, are reported separately and never overwrite this frozen phase.

### Observed failure feedback

- four-hop-shared-witness-seed-20261010, trial 1, raw-fact-reasoning, turn 2: answer_not_verified; thinking 54488; feedback `{"verification": "not_verified"}`.
- four-hop-shared-witness-seed-20261010, trial 1, raw-fact-reasoning, turn 3: answer_not_verified; thinking 39445; feedback `{"verification": "not_verified"}`.
- four-hop-shared-witness-seed-20261010, trial 1, raw-fact-reasoning, turn 4: answer_not_verified; thinking 411; feedback `{"verification": "not_verified"}`.
- four-hop-shared-witness-seed-20261010, trial 1, raw-fact-reasoning, turn 5: answer_not_verified; thinking 721; feedback `{"verification": "not_verified"}`.
- four-hop-shared-witness-seed-20261010, trial 1, scheme-evidence, turn 2: action_failure; thinking 1402; feedback `{"error": "head must be nonempty atom array"}`.
- four-hop-shared-witness-seed-20261010, trial 2, raw-fact-reasoning, turn 2: answer_not_verified; thinking 32334; feedback `{"verification": "not_verified"}`.
- four-hop-shared-witness-seed-20261010, trial 2, scheme-evidence, turn 2: action_failure; thinking 849; feedback `{"error": "head must be nonempty atom array"}`.
- scoped-union-recursive-branch-seed-20261212, trial 1, scheme-evidence, turn 2: action_failure; thinking 1084; feedback `{"error": "head must be nonempty atom array"}`.
- scoped-union-recursive-branch-seed-20261212, trial 2, raw-fact-reasoning, turn 2: output_budget_exhausted; thinking 131072; feedback `[]`.
- scoped-union-recursive-branch-seed-20261212, trial 2, scheme-evidence, turn 2: action_failure; thinking 15037; feedback `{"error": "head must be nonempty atom array"}`.

## Evidence mechanism audit

- raw-fact-reasoning: 0/8 trajectories published Scheme evidence; 0 later queries explicitly extended a published alias.
- scheme-evidence: 8/8 trajectories published Scheme evidence; 0 later queries explicitly extended a published alias.

Later model calls exposed to published evidence: 13. Completed retained-path hits: 0. Exposure is not proof that the model causally used each item. Adoption is self-selected; a treatment-only subset is descriptive, not a randomized causal estimate. Without explicit alias extension or a separate execution-only ablation, lower thinking cannot be attributed specifically to cross-round reuse rather than query execution assistance. The experiment does not identify exact redundant internal token spans.

## Resource accounting

Total provider calls: **54**. Conservative peak-price estimate: **USD 1.023847**. Under the published weekend off-peak rates, the same usage prices at approximately **USD 0.511923**; no invoice or account balance was retrieved. Prices: USD 0.30/M uncached input, 0.006/M cached input and 1.20/M output at peak, half off-peak. [Official pricing](https://api-docs.deepseek.com/quick_start/pricing/). Token usage, rather than visible answer byte count, is the basis. Scheme semantic reuse and provider prefix caching are separate mechanisms.

## Interpretation and limitations

These are four synthetic compound questions with two trials per condition, not a population accuracy estimate or an independently annotated real-world benchmark. Development choices are known; freezing prevents outcome-adaptive rewriting of these primary trials but does not create an external held-out benchmark. An execution-capable agent baseline would be needed to assess how much benefit is specific to ASCENT. A stable 40–50% claim needs preserved quality, repeated independent workloads and an ablation isolating retained evidence. Source withdrawal and semantic mutation controls passed offline; those controls are not additional paid model tasks.

The actual frozen CFFI engine executed the evidence. Existing Lean/Quint correspondence qualifies bounded operator and reuse conditions; it does not prove natural-language intent, hidden thinking, arbitrary compilation or empirical token savings. Fresh-source Ubuntu CI is a distinct gate.

## Evidence files

- [Frozen plan](../../../.cache/ascent/archived-runs/docs/research/agent-inference/tool-thinking-plan.json)
- [Offline Scheme/oracle qualification](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-qualification.json)
- [Real-model receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/tool-thinking-result.json)
- [Audited cumulative costs and pairs](../../../.cache/ascent/archived-runs/docs/research/agent-inference/tool-thinking-audit.json)

Requests and responses are retained under `.cache/ascent/movie-study/compound-thinking-tools-validated-real-20261010/`; the tracked artifact manifest includes their identities. Frozen outcomes and costs are unchanged.

## Corrected-protocol exhaustion and complete-history continuation

The union question, trial 2, raw-fact control consumed **131,362 thinking tokens** and exhausted one response without a submitted answer. Its complete prior history, including the incomplete reasoning item, was forwarded unchanged into at most two additional requests at the same 131,072 ceiling. The primary result remains censored.

The continuation used **2 extra call(s)** and **36,149 additional thinking tokens**. Cumulative effort is **167,511 tokens**; independently verified: **True**. Additional peak-price estimate: USD **0.047384**. [Complete-history recovery receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/tool-thinking-recovery.json).

After this adaptive repair, all eight control trajectories and all eight Scheme trajectories have correct answers, with **596,491 vs 199,765 thinking tokens**; observed reduction **66.51%**. This supplementary total includes the original 131,362-token failure and its repair, but is not the frozen matched-policy primary score.

## Original frozen protocol: preserved diagnostic results

These results remain separate because this protocol did not retain actual provider thinking history. Exhausted trajectories are censored; their thinking cost is still charged.

## Accuracy and total consumed work

| Condition | Verified / trajectories | Accuracy | First submitted answer correct / assigned | Model calls | Thinking tokens | Input tokens | Output incl. thinking | Scheme/local action seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| raw-fact-reasoning | 5/8 | 62.5% | 4/8 | 17 | 448,691 | 79,586 | 450,785 | 0.0428 |
| scheme-evidence | 7/8 | 87.5% | 7/8 | 26 | 369,616 | 210,196 | 381,504 | 1.0131 |

All consumed work includes unsuccessful trajectories. Usage completeness is recorded in the audit. Thinking tokens are a subset of output tokens, not an extra billable amount. Local action time includes scans, oracle grading and failed action handling as well as Scheme queries; it is not pure engine compute time. Runtime initialization and pre-turn store admission are outside that timer.

## First-correct trajectories

| Question | Trial | Condition | Verified | Calls through first correct / censoring | Thinking tokens | Observable actions |
|---|---:|---|---|---:|---:|---|
| four-hop-shared-witness-seed-20261010 | 1 | raw-fact-reasoning | Yes | 2 | 41,664 | scan → answer |
| four-hop-shared-witness-seed-20261010 | 1 | scheme-evidence | Yes | 3 | 22,992 | scan → query → answer |
| four-hop-shared-witness-seed-20261010 | 2 | scheme-evidence | Yes | 5 | 65,110 | scan → query → invalid action shape → query → answer |
| four-hop-shared-witness-seed-20261010 | 2 | raw-fact-reasoning | Yes | 3 | 77,410 | scan → answer → answer |
| recursive-clean-bridge-seed-20261111 | 1 | raw-fact-reasoning | Yes | 2 | 46,488 | scan → answer |
| recursive-clean-bridge-seed-20261111 | 1 | scheme-evidence | Yes | 3 | 39,443 | scan → query → answer |
| recursive-clean-bridge-seed-20261111 | 2 | scheme-evidence | Yes | 2 | 41,366 | scan → answer |
| recursive-clean-bridge-seed-20261111 | 2 | raw-fact-reasoning | No: censored | 2 | 65,990 | scan → invalid action shape |
| scoped-union-recursive-branch-seed-20261212 | 1 | raw-fact-reasoning | No: censored | 2 | 65,741 | scan → invalid action shape |
| scoped-union-recursive-branch-seed-20261212 | 1 | scheme-evidence | No: censored | 2 | 65,893 | scan → invalid action shape |
| scoped-union-recursive-branch-seed-20261212 | 2 | scheme-evidence | Yes | 5 | 56,409 | scan → query → invalid action shape → query → answer |
| scoped-union-recursive-branch-seed-20261212 | 2 | raw-fact-reasoning | No: censored | 2 | 65,983 | scan → invalid action shape |
| all-targets-positive-reach-seed-20261313 | 1 | raw-fact-reasoning | Yes | 2 | 43,498 | scan → answer |
| all-targets-positive-reach-seed-20261313 | 1 | scheme-evidence | Yes | 4 | 23,465 | scan → query → query → answer |
| all-targets-positive-reach-seed-20261313 | 2 | scheme-evidence | Yes | 2 | 54,938 | scan → answer |
| all-targets-positive-reach-seed-20261313 | 2 | raw-fact-reasoning | Yes | 2 | 41,917 | scan → answer |

## Results by question family

| Family | Control verified | Scheme verified | Control thinking | Scheme thinking | Reduction on jointly verified trials |
|---|---:|---:|---:|---:|---:|
| four-hop-shared-witness | 2/2 | 2/2 | 119,074 | 88,102 | 26.01% (2 pairs) |
| recursive-clean-bridge | 1/2 | 2/2 | 112,478 | 80,809 | 15.15% (1 pairs) |
| scoped-union-recursive-branch | 0/2 | 1/2 | 131,724 | 122,302 | Undefined (unverified pair) (0 pairs) |
| all-targets-positive-reach | 2/2 | 2/2 | 85,415 | 78,403 | 8.21% (2 pairs) |

## Matched thinking reductions

| Question | Trial | Both verified | Thinking reduction | Turn reduction |
|---|---:|---|---:|---:|
| four-hop-shared-witness-seed-20261010 | 1 | Yes | 44.82% | -50.00% |
| four-hop-shared-witness-seed-20261010 | 2 | Yes | 15.89% | -66.67% |
| recursive-clean-bridge-seed-20261111 | 1 | Yes | 15.15% | -50.00% |
| recursive-clean-bridge-seed-20261111 | 2 | No | Undefined (unverified pair) | Undefined (unverified pair) |
| scoped-union-recursive-branch-seed-20261212 | 1 | No | Undefined (unverified pair) | Undefined (unverified pair) |
| scoped-union-recursive-branch-seed-20261212 | 2 | No | Undefined (unverified pair) | Undefined (unverified pair) |
| all-targets-positive-reach-seed-20261313 | 1 | Yes | 46.05% | -100.00% |
| all-targets-positive-reach-seed-20261313 | 2 | Yes | -31.06% | 0.00% |

Jointly verified pairs: **5/8**. Measurable thinking pairs: 5. Weighted cumulative thinking reduction on that measurable subset: **17.94%**. Positive means less thinking; negative means more. Read this subset together with full-condition accuracy and censored consumed costs; it does not erase failed trajectories.

## Failure and repair costs

| Condition | Failed attempts | Failure + repair calls | Failure + repair thinking | Peak-price estimate USD |
|---|---:|---:|---:|---:|
| raw-fact-reasoning | 4 | 5 | 273,739 | 0.339147 |
| scheme-evidence | 6 | 12 | 208,379 | 0.276518 |

Failure + repair includes the first failed attempt and every later call until verification or censoring. It is a measured suffix cost, not proof that every token was avoidable. Ordinary successful evidence-building before a failure remains charged in the trajectory total. Adaptive follow-up costs, when present, are reported separately and never overwrite this frozen phase.

### Observed failure feedback

- four-hop-shared-witness-seed-20261010, trial 2, scheme-evidence, turn 2: action_failure; thinking 63648; feedback `{"error": "source/declaration collision"}`.
- four-hop-shared-witness-seed-20261010, trial 2, scheme-evidence, turn 3: action_failure; thinking 600; feedback `{"error": "action unavailable in this arm"}`.
- four-hop-shared-witness-seed-20261010, trial 2, raw-fact-reasoning, turn 2: answer_not_verified; thinking 42154; feedback `{"verification": "not_verified"}`.
- recursive-clean-bridge-seed-20261111, trial 2, raw-fact-reasoning, turn 2: output_budget_exhausted; thinking 65536; feedback `[]`.
- scoped-union-recursive-branch-seed-20261212, trial 1, raw-fact-reasoning, turn 2: output_budget_exhausted; thinking 65536; feedback `[]`.
- scoped-union-recursive-branch-seed-20261212, trial 1, scheme-evidence, turn 2: output_budget_exhausted; thinking 65536; feedback `[]`.
- scoped-union-recursive-branch-seed-20261212, trial 2, scheme-evidence, turn 2: action_failure; thinking 38742; feedback `{"error": "head must be nonempty atom array"}`.
- scoped-union-recursive-branch-seed-20261212, trial 2, scheme-evidence, turn 3: action_failure; thinking 584; feedback `{"error": "Expecting value: line 1 column 1 (char 0)"}`.
- scoped-union-recursive-branch-seed-20261212, trial 2, raw-fact-reasoning, turn 2: output_budget_exhausted; thinking 65536; feedback `[]`.
- all-targets-positive-reach-seed-20261313, trial 1, scheme-evidence, turn 2: action_failure; thinking 1791; feedback `{"error": "head must be nonempty atom array"}`.

## Evidence mechanism audit

- raw-fact-reasoning: 0/8 trajectories published Scheme evidence; 0 later queries explicitly extended a published alias.
- scheme-evidence: 5/8 trajectories published Scheme evidence; 0 later queries explicitly extended a published alias.

Later model calls exposed to published evidence: 5. Completed retained-path hits: 0. Exposure is not proof that the model causally used each item. Adoption is self-selected; a treatment-only subset is descriptive, not a randomized causal estimate. Without explicit alias extension or a separate execution-only ablation, lower thinking cannot be attributed specifically to cross-round reuse rather than query execution assistance. The experiment does not identify exact redundant internal token spans.

## Resource accounting

Total provider calls: **43**. Conservative peak-price estimate: **USD 1.046732**. Under the published weekend off-peak rates, the same usage prices at approximately **USD 0.523366**; no invoice or account balance was retrieved. Prices: USD 0.30/M uncached input, 0.006/M cached input and 1.20/M output at peak, half off-peak. [Official pricing](https://api-docs.deepseek.com/quick_start/pricing/). Token usage, rather than visible answer byte count, is the basis. Scheme semantic reuse and provider prefix caching are separate mechanisms.

## Interpretation and limitations

These are four synthetic compound questions with two trials per condition, not a population accuracy estimate or an independently annotated real-world benchmark. Development choices are known; freezing prevents outcome-adaptive rewriting of these primary trials but does not create an external held-out benchmark. An execution-capable agent baseline would be needed to assess how much benefit is specific to ASCENT. A stable 40–50% claim needs preserved quality, repeated independent workloads and an ablation isolating retained evidence. Source withdrawal and semantic mutation controls passed offline; those controls are not additional paid model tasks.

The actual frozen CFFI engine executed the evidence. Existing Lean/Quint correspondence qualifies bounded operator and reuse conditions; it does not prove natural-language intent, hidden thinking, arbitrary compilation or empirical token savings. Fresh-source Ubuntu CI is a distinct gate.

## Evidence files

- [Frozen plan](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-plan.json)
- [Offline Scheme/oracle qualification](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-qualification.json)
- [Real-model receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-result.json)
- [Audited cumulative costs and pairs](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-audit.json)

Requests and responses are retained under `.cache/ascent/movie-study/compound-thinking-real-20261010/`; the tracked artifact manifest includes their identities. Frozen outcomes and costs are unchanged.

## Adaptive recovery of every original censored trajectory

All four censored original trajectories were continued under the original external-ledger interface, with an equal 131,072 ceiling and at most two additional calls each. This is an adaptive intervention, not a replacement primary score. The model received binary verification only, never gold values.

| Question | Trial | Condition | Original thinking | Additional repair thinking | Total to verification/censoring | Verified | Extra calls |
|---|---:|---|---:|---:|---:|---|---:|
| recursive-clean-bridge-seed-20261111 | 2 | raw-fact-reasoning | 65,990 | 51,357 | 117,347 | True | 1 |
| scoped-union-recursive-branch-seed-20261212 | 1 | raw-fact-reasoning | 65,741 | 119,346 | 185,087 | True | 1 |
| scoped-union-recursive-branch-seed-20261212 | 1 | scheme-evidence | 65,893 | 9,778 | 75,671 | True | 2 |
| scoped-union-recursive-branch-seed-20261212 | 2 | raw-fact-reasoning | 65,983 | 66,468 | 132,451 | True | 1 |

Adaptive recovery consumed **246,949 additional thinking tokens**; peak-price estimate USD **0.313112**. [Recovery receipt](../../../.cache/ascent/archived-runs/docs/research/agent-inference/compound-thinking-recovery.json).

## Financial and execution accounting

All accepted calls across the three phases price at **USD 2.431075 peak**, or approximately **USD 1.215538 at published weekend off-peak rates**. Rejected-request charges, local machine costs and invoices are unknown. This estimate uses all input and output usage, including reasoning; it is not the primary reasoning-saving metric. [Official prices](https://api-docs.deepseek.com/quick_start/pricing/).

The official alias currently maps to V4.1 Flash. The response metadata resolves to the reported alias; no immutable provider model build is pinned. This limits reproduction across future alias updates. No fixed wall-clock deadline was widened to manufacture success; an actual streaming-progress idle watchdog remains active. The corrected study ran at most two active requests, plus the separately recorded legacy recovery request during overlap. Provider-seconds summed across calls are not elapsed wall time.

## Architecture, failure reflection and evidence limits

The production conversation adapter preserves provider state and enforces paired, unique tool calls before the next stateless request. The model may scan facts, write a derivation, observe a Scheme validation error, repair it and continue thinking with source-bound evidence. Query syntax failures and verification failures are surfaced and charged. The running CFFI artifact is hash-bound; identical sources and the same compiled engine were used in both phases.

Four-hop and union semantics require shared witnesses and branch-specific negation. Recursive closure must allow dirty intermediates when only endpoints are constrained. Universal coverage must use every target and positive-length reach, including nonempty cycles for self-reach. Offline qualification compares Scheme against an independent Python BFS/set oracle, tests source withdrawal, and rejects three concrete semantic mutations. These executable checks are stronger than agreeing with a model explanation, but do not prove arbitrary natural-language intent.

Existing Lean and Quint operator/refinement obligations qualify their stated finite-source and reuse assumptions. This delivery adds no new theorem proving the four English questions or hidden thinking correct. The empirical experiment measures thinking effort, not internal duplicated-token spans. An execution-only ablation and an execution-capable control are still needed to attribute savings specifically to retained cross-round evidence. Exact-repeat zero-call reuse is a separate mechanism and is not counted as first-answer enhancement in these fresh-store trials.

Failures identify a practical integration cost: rule admission errors can consume additional model rounds even when the intended relation is straightforward. Typed feedback, full conversation continuity and source-bound receipts now make those repair rounds measurable. The observed per-trial increases must remain visible. Two repetitions on four synthetic sources cannot establish sustained 40–50% savings across independent complex workloads.

## Reproducibility and validation

All 48 Python tests passed locally, including real engine initialization and watchdog tests. Thirteen focused history, cumulative-cost, censoring, complete-history recovery, progress-watchdog and matched-tool tests passed after report changes. The earlier exact-head CI revision `f282eca7684b363af362d7f7872f45806a8cca6b` passed; CI on this delivery is recorded separately after push.

[Artifact manifest](../../../.cache/ascent/archived-runs/docs/research/agent-inference/thinking-artifact-manifest.json) records plan/result/library/source hashes, request/response/raw-output hashes and verified history continuity for every corrected request. Provider reasoning is not printed in this report. Cache files retain the raw provider receipts locally; tracked manifests do not imply that those ignored raw files are downloadable from GitHub. [Transport rejection audit](../../../.cache/ascent/archived-runs/docs/research/agent-inference/thinking-tool-transport-audit.json) preserves the exact typed interface failure and unknown-usage boundary.

## Post-run external answer audit

After every paid run finished, submitted answer sets were compared with the private oracle to characterize failures. These counts were never returned to the model during the experiment. Missing/extra counts describe observable answer errors; they do not establish the hidden reasoning cause.

| Phase | Question | Trial | Turn | Submitted unique actors | Expected actors | Missing | Extra | Outside source domain |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| compound | four-hop-shared-witness-seed-20261010 | 2 | 2 | 27 | 25 | 0 | 2 | 0 |
| tool | four-hop-shared-witness-seed-20261010 | 1 | 2 | 25 | 25 | 25 | 25 | 25 |
| tool | four-hop-shared-witness-seed-20261010 | 1 | 3 | 17 | 25 | 25 | 17 | 17 |
| tool | four-hop-shared-witness-seed-20261010 | 1 | 4 | 12 | 25 | 25 | 12 | 12 |
| tool | four-hop-shared-witness-seed-20261010 | 1 | 5 | 12 | 25 | 25 | 12 | 12 |
| tool | four-hop-shared-witness-seed-20261010 | 2 | 2 | 27 | 25 | 0 | 2 | 0 |

The four incorrect submissions in corrected four-hop trial 1 used identifiers outside the finite source domain. This is an observable entity-output failure, and its repair cost contributes to the measured reduction. It does not by itself demonstrate improved logical inference. Excluding that affected pair as a descriptive sensitivity check leaves six jointly verified pairs with a 55.16% thinking reduction; this exclusion is post-run analysis, not a replacement primary score. A future common source-identifier admission check and an execution-capable baseline are needed to distinguish identifier handling from logical reasoning enhancement.

All eight Scheme first submitted answers were correct in the corrected phase. Four Scheme response failures were rule-head shape admission errors; all were repaired. The recursive first pair increased thinking from 27,030 to 33,125 tokens (22.55% more) even though the answer was correct. Evidence construction can cost more than direct reasoning on an individual instance. Two recursive pairs aggregate to a 23.63% reduction, so the negative trial remains visible.

The first complete-history continuation of the exhausted union control also submitted an incorrect answer before a second continuation verified it. Both calls and the original exhausted response are included in the supplementary total. This is an observed failure-repair path, not a free successful retry.
