# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Render the frozen total budget comparison and retain negative quality findings."


def _render_budget_text(aggregates, pairs, rows, shared, plan):
    """Own the render budget text phase and retain its evidence checks."""
    table = "\n".join(
        (
            "| "
            + str(p["case"])
            + " / "
            + str(p["phase"])
            + " | "
            + (
                "—"
                if p["fresh"]["objectiveGap"] is None
                else str(p["fresh"]["objectiveGap"])
            )
            + " | "
            + (
                "—"
                if p["retained"]["objectiveGap"] is None
                else str(p["retained"]["objectiveGap"])
            )
            + " | "
            + str(p["fresh"]["totalTokens"])
            + " / "
            + str(p["retained"]["totalTokens"])
            + " | "
            + str(p["fresh"]["uniqueFeasibleSchedules"])
            + " / "
            + str(p["retained"]["uniqueFeasibleSchedules"])
            + " | "
            + str(p["fresh"]["maxProperPrefixDepth"])
            + " / "
            + str(p["retained"]["maxProperPrefixDepth"])
            + " |"
            for p in pairs
        )
    )
    f = aggregates["fresh"]
    t = aggregates["retained"]
    text = f"""# Matched-evidence, total-budget native cache pilot

This pilot did not establish reduced thinking, deeper exploration or better quality from retained cache state. Fresh submitted {f["submitted"]}/4 schedules and used {f["totalTokens"]:,} gross tokens; retained submitted {t["submitted"]}/4 and used {t["totalTokens"]:,}. Native proof-packet construction occurred {f["freshNativePacketSolves"]} versus {t["freshNativePacketSolves"]} times. Aggregate native packet roundtrip time did not improve. These are descriptive small-sample outcomes, not causal degradation or improvement claims.

Both arms receive byte-identical initial Fact/derivation packets. Confirmatory study: {len(rows)} phases, four task/goal pairs, 14 and 16 jobs with immutable adjacent-pair transition penalties; independent exact direct-edge subset-plus-last DP grader frozen before paid calibration or confirmatory calls. No model grader, hidden-optimum feedback, full-answer cache, retries or failed-trial deletion.

All phases share the 98,304 gross-token ceiling: every input and every output, including thinking. Replayed history and provider prefix-cache hits count as full input. Reasoning is a subset of output and is not added twice. This is a common ceiling, not artificially equal realized spend. Before requests the controller conservatively reserves compact UTF-8 request bytes plus framing allowances. This is an empirical allowance, not a guaranteed exact tokenizer. Returned provider usage decides admission; any reserve violation, budget overshoot or unknown usage is a protocol failure. [DeepSeek identifies returned usage as authoritative](https://api-docs.deepseek.com/quick_start/token_usage/).

Each task minimizes weighted completion cost plus fixed adjacent-pair penalties. Penalties do not change completion times. The source precedence graph, durations and penalty matrix remain fixed while weights change between history-reset phases. The admitted Fact/derivation packet certifies precedence; the matrix is frozen task data, not an ASCENT arithmetic proof. The independent grader checks the entire composite objective.

A common controller allows two high-reasoning construction/refinement calls and then a forced non-thinking `submit` of the best already evaluated candidate. This finalizer never sees the hidden optimum. Its feedback and input tokens are charged normally. This finalizer is reached only if earlier response calls complete and input reservation allows another call; a censored refinement stops the phase and leaves the best candidate available for the any-time grade, without claiming successful completion. This is a common search policy, not a cache-arm advantage. [DeepSeek supports non-thinking effort and named tool choice](https://api-docs.deepseek.com/api/create-response/).

## Results

| Task / goal phase | Fresh objective gap | Retained objective gap | Gross tokens F / R | Unique feasible schedules F / R | Proper-prefix depth F / R |
| --- | ---: | ---: | ---: | ---: | ---: |
{table}

Fresh: {f["submitted"]}/4 submitted, {f["optimal"]}/4 optimal observed candidates ({f["submittedOptimal"]} successfully submitted), {f["failures"]} failed/censored phases. Retained: {t["submitted"]}/4 submitted, {t["optimal"]}/4 optimal observed candidates ({t["submittedOptimal"]} successfully submitted), {t["failures"]} failed/censored phases. Objective gaps use the submitted schedule; if none was submitted, the best evaluated candidate is separately labeled by the submission/failure fields. Invalid or absent candidates retain null gaps. Non-optimal submitted outcomes remain quality negatives even when their protocol completed.

Fresh gross tokens: {f["totalTokens"]}; retained: {t["totalTokens"]}. Reasoning tokens: {f["reasoningTokens"]} / {t["reasoningTokens"]}. Packet-covered Fact requests: {f["factorChecksAlreadyCoveredByPacket"]} / {t["factorChecksAlreadyCoveredByPacket"]}; duplicate requests within a phase: {f["duplicateFactRequests"]} / {t["duplicateFactRequests"]}. Unique feasible schedules: {f["uniqueFeasibleSchedules"]} / {t["uniqueFeasibleSchedules"]}. Branching prefix parents: {f["branchedPrefixParents"]} / {t["branchedPrefixParents"]}.

Native packet/factor roundtrip time: {f["nativePacketAndFactorSeconds"]:.4f}s / {t["nativePacketAndFactorSeconds"]:.4f}s. Fresh shared-packet solves: {f["freshNativePacketSolves"]} / {t["freshNativePacketSolves"]}; retained shared-packet lookups: {f["retainedNativePacketLookups"]} / {t["retainedNativePacketLookups"]}. Fresh native Fact solves: {f["freshNativeFactorSolves"]} / {t["freshNativeFactorSolves"]}; retained Fact lookups: {f["retainedNativeFactorLookups"]} / {t["retainedNativeFactorLookups"]}. Audit proof bytes written: {f["proofBytesWritten"]} / {t["proofBytesWritten"]}. Time includes native IPC, checking and certificate export. Individual Fact-tool proof writes are included in per-tool costs. Process startup and shared-packet Python proof-file writes are not separately timed; these timings are not an end-to-end native speed claim. Grading time is recorded separately, outside model-visible inference.

## Evidence boundaries

Means of quality over valid candidates exclude missing candidates and must not be read as arm-level improvement: retained has more missing results. Use paired gaps together with validity, submission and censoring. Same source, goal, initial-question bytes, evidence hash and deterministic tool-reply policy apply within each pair. {shared} shared requested tool replies were compared for exact equality. Cache flags, timings and native provenance receipts never enter model input. Later model histories can diverge because sampling is stochastic; backend identity and seed determinism are unavailable. The counterbalanced two-task sample supports descriptive comparisons, not a significance claim or a stable model-level causal speedup.

With identical visible evidence, retained native state directly avoids external recomputation. It supplies no extra model information or token-allocation instruction relative to fresh. Differences in reasoning tokens, schedules or quality cannot establish a causal reduction in repeated internal thinking. Observable repeated Fact/tool/path checks are operational proxies; Semantic repetition in the returned reasoning text is not annotated or measured; unexposed internal states are unavailable. Prefix length alone is not proof of deeper reasoning: proper-prefix depth, distinct feasible candidates and prefix branching are reported separately. No finding of model-level efficiency or quality improvement is inferred from native-cache savings alone. This cache certifies precedence factors; it does not memoize the arithmetic of weighted completion/transition costs or prove optimality. Repeated tool signatures do not identify semantic overlap among different reasoning paths.

An initial separately frozen calibration exhausted both 16,384 output allowances entirely in thinking: no tool calls, no candidate schedules, hardness gate failed. Those two censored paid phases remain under `censored-calibration-16384/` and in the ledger; they are not pooled into the revised calibration or confirmatory rates. The revised protocol keeps the same 98,304 gross-token ceiling, tasks and grader, raises the per-call output cap to 32,768, and asks for an initial feasible candidate before refinement plus explicit alternative branch probes.

The v2 plain weighted-completion calibration then found optimal candidates in both tasks (despite 164,370 and 212,214,720 feasible schedules), followed by censored further thinking without submission. It also failed the predeclared non-optimal-quality gate. Those stages are under `saturated-calibration-plain/`; the former native artifacts remain byte-preserved in `pretransition-snapshot/`. They are not pooled into confirmatory quality rates. The v3 task adds fixed transition penalties and freezes the exact subset-plus-last grader, initial-candidate policy and bounded finalization before new calibration.

Disjoint calibration tasks and all their paid outcomes are preserved in the ledger. The v3 task definitions, model request policy and grader were frozen before transition calibration. After calibration, before any confirmatory outcome, v4 froze any-time candidate quality as the primary endpoint and kept submission/censoring as separate failures. Eighteen task, artifact and model-policy fields match exactly between v3 and v4; only admission/metadata changed. The stricter original calibration gate and controller are retained separately. No calibration censoring was reclassified as success. The hardness gate required at least one valid non-optimal best-observed calibration candidate with known in-budget usage; confirmatory failures and outcomes were never used to choose tasks. Exact graders qualify against ten seven-job exhaustive-enumeration controls, hand-computed three-job optima with and without transition penalties, invalid schedules and their own recovered exact witnesses. This is finite experimental qualification, not a Lean proof of the new DP implementation.

The new bridge and grader are compiled against the prior frozen production kernel, whose candidate source files match the current checkout. All inherited compiler artifacts and new executable bytes are bound in the plan; this is not a new whole-repository build at `{plan["headAtFreeze"]}`. Prior proof/Lean/Quint correspondence remains scoped to the old bounded retained-evidence checks. Stored certificates are audit exports; retained lookup uses admitted in-memory native receipts, not replay/re-admission from disk.

The retained 16-job transfer phase stopped with 50,431 observed gross tokens because conservative reservation would reject another request. This is an estimate-driven stop, not proof that the actual 98,304-token ceiling was exhausted. The guard is deliberately conservative and can underuse the available budget. Both arms use the same guard; this pilot cannot claim that the entire common allowance was spent on productive exploration.

## Reproduction and retained failures

Frozen plan, qualification, native build failures, complete requests, SSE traces, responses and per-phase receipts remain under `.cache/ascent/factor-budget/`. The portable ledger retains every calibration and confirmatory phase, all returned provider responses including failures, exact usage and every raw-file hash. Secrets and authorization headers are never recorded. No invoice dollar amount is inferred. The original pilot and its censored round are unchanged.

Commands: `PYTHONPATH=workbench/src:python/src python3 -m agentic_ai_lab_testing.assessment_studies.factor_budget qualify`, then `freeze`, `calibrate`, `run`, and `python3 -m agentic_ai_lab_testing.assessment_studies.factor_budget_report`. Paid directories are exclusive: rerunning never overwrites an existing trial. Hash checks bind the frozen controller, grader, qualification and native artifacts before and after each run.
"""
    return text
