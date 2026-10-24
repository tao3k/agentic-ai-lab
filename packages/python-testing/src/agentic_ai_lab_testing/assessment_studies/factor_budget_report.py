# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Descriptive paired summaries, preserving failed trials and all raw receipts."""
import json, hashlib, statistics
from pathlib import Path
ROOT = Path.cwd()
BASE = ROOT / '.cache/ascent/factor-budget'
DOC = ROOT / '.cache/ascent/research-reports/agent-inference'

DOC.mkdir(parents=True, exist_ok=True)

def sha(b):
    return hashlib.sha256(b).hexdigest()

def save(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + '\n')

def metrics(r):
    usages = [c['usage'] for c in r['calls'] if isinstance(c.get('usage'), dict)]
    factors = [t for t in r['tools'] if t['name'] == 'factor']
    valid = [t for t in r['tools'] if t['name'] in ('evaluate', 'submit') and t['result'].get('valid')]
    orders = {tuple(t['arguments']['order']) for t in valid}
    prefixes = {tuple(t['arguments']['prefix']) for t in r['tools'] if t['name'] == 'explore' and t['result'].get('validPrefix')}
    proper = [p for p in prefixes if len(p) < len(r['grade']['oracle']['optimalOrder'])]
    parents = {}
    for p in prefixes:
        if p:
            parents.setdefault(p[:-1], set()).add(p[-1])
    return {'inputTokens': sum((u.get('input_tokens', 0) for u in usages)), 'outputTokens': sum((u.get('output_tokens', 0) for u in usages)), 'reasoningTokens': sum((u.get('output_tokens_details', {}).get('reasoning_tokens', 0) for u in usages)), 'providerCachedInputTokens': sum((u.get('input_tokens_details', {}).get('cached_tokens', 0) for u in usages)), 'totalTokens': r['observedTotalTokens'], 'missingUsageCalls': sum((not isinstance(c.get('usage'), dict) for c in r['calls'])), 'factorChecksAlreadyCoveredByPacket': len(factors), 'duplicateFactRequests': sum((t.get('duplicateWithinPhase', False) for t in factors)), 'duplicateExploreRequests': sum((t.get('duplicateWithinPhase', False) for t in r['tools'] if t['name'] == 'explore')), 'duplicateEvaluateRequests': sum((t.get('duplicateWithinPhase', False) for t in r['tools'] if t['name'] == 'evaluate')), 'uniqueFeasibleSchedules': len(orders), 'uniqueValidPrefixes': len(prefixes), 'maxProperPrefixDepth': max(map(len, proper), default=0), 'branchedPrefixParents': sum((len(v) > 1 for v in parents.values())), 'freshNativePacketSolves':int(not r['packet']['reused']),'retainedNativePacketLookups':int(r['packet']['reused']),'freshNativeFactorSolves': sum((t.get('nativeReceipt', {}).get('freshNativeSolve', False) for t in factors)), 'retainedNativeFactorLookups': sum((t.get('nativeReceipt', {}).get('reused', False) for t in factors)), 'nativePacketAndFactorSeconds': r['packet']['nativeSeconds'] + sum((t.get('nativeSeconds', 0) for t in factors)), 'totalToolSeconds': sum((t['seconds'] for t in r['tools'])), 'proofBytesWritten': r['packet']['proofBytes'] + sum((t.get('proofBytes', 0) for t in factors)), 'objectiveGap': r['grade']['gap'] if r['grade']['valid'] else None, 'relativeGap': r['grade']['gap'] / r['grade']['oracle']['optimum'] if r['grade']['valid'] else None, 'optimal': r['grade']['optimal'], 'submitted': r['submitted'], 'failure': r['failure']}

def main():
    plan = json.loads((BASE / 'frozen-plan.json').read_text())
    cal = json.loads((BASE / 'calibration/records.json').read_text())
    rows = json.loads((BASE / 'paid/records.json').read_text())
    pairs = []
    for c in plan['cases']:
        for phase in (0, 1):
            f = next((r for r in rows if r['case'] == c['id'] and r['phase'] == phase and (r['arm'] == 'fresh')))
            t = next((r for r in rows if r['case'] == c['id'] and r['phase'] == phase and (r['arm'] == 'retained')))
            assert f['initialInputSha256'] == t['initialInputSha256'] and f['packet']['proofSha256'] == t['packet']['proofSha256']
            fm, tm = (metrics(f), metrics(t))
            pairs.append({'case': c['id'], 'phase': phase, 'initialInputsAndPacketsMatched': True, 'fresh': fm, 'retained': tm, 'retainedMinusFresh': {k: tm[k] - fm[k] for k in ('totalTokens', 'reasoningTokens', 'factorChecksAlreadyCoveredByPacket', 'uniqueFeasibleSchedules', 'maxProperPrefixDepth', 'branchedPrefixParents')}, 'qualityGapDelta': tm['objectiveGap'] - fm['objectiveGap'] if tm['objectiveGap'] is not None and fm['objectiveGap'] is not None else None})
    shared = 0
    for c in plan['cases']:
        for phase in (0, 1):
            group = [r for r in rows if r['case'] == c['id'] and r['phase'] == phase]
            maps = []
            for r in group:
                d = {}
                for t in r['tools']:
                    if t.get('failure'):
                        continue
                    key = t['name'] + json.dumps(t.get('arguments'), sort_keys=True)
                    if key in d:
                        assert d[key] == t['result']
                    d[key] = t['result']
                maps.append(d)
            for key in maps[0].keys() & maps[1].keys():
                assert maps[0][key] == maps[1][key]
                shared += 1
    aggregates = {}
    for arm in ('fresh', 'retained'):
        rs = [r for r in rows if r['arm'] == arm]
        ms = [metrics(r) for r in rs]
        aggregates[arm] = {'phases': len(rs), 'submitted': sum((m['submitted'] for m in ms)), 'optimal': sum((m['optimal'] for m in ms)), 'submittedOptimal':sum(m['optimal'] and m['submitted'] and m['failure'] is None for m in ms), 'failures': sum((m['failure'] is not None for m in ms)), 'validCandidates': sum((r['grade']['valid'] for r in rs)), 'meanRelativeGapOnValid': statistics.mean((m['relativeGap'] for m in ms if m['relativeGap'] is not None)) if any((m['relativeGap'] is not None for m in ms)) else None, **{k: sum((m[k] for m in ms)) for k in ('inputTokens', 'outputTokens', 'reasoningTokens', 'totalTokens', 'providerCachedInputTokens', 'missingUsageCalls', 'factorChecksAlreadyCoveredByPacket', 'duplicateFactRequests', 'duplicateExploreRequests', 'duplicateEvaluateRequests', 'uniqueFeasibleSchedules', 'uniqueValidPrefixes', 'branchedPrefixParents', 'nativePacketAndFactorSeconds', 'totalToolSeconds', 'proofBytesWritten', 'freshNativeFactorSolves', 'retainedNativeFactorLookups', 'freshNativePacketSolves','retainedNativePacketLookups')}}
    raw = {str(p.relative_to(BASE)): sha(p.read_bytes()) for d in ('calibration', 'paid', 'censored-calibration-16384', 'saturated-calibration-plain') for p in (BASE / d).rglob('*') if p.is_file()}
    responses = {str(p.relative_to(BASE)): json.loads(p.read_text()) for d in ('calibration', 'paid', 'censored-calibration-16384', 'saturated-calibration-plain') for p in (BASE / d).glob('*/*.response.json')}
    requests = {str(p.relative_to(BASE)): json.loads(p.read_text()) for d in ('calibration', 'paid', 'censored-calibration-16384', 'saturated-calibration-plain') for p in (BASE / d).glob('*/*.request.json')}
    proofs = {p.stem: json.loads(p.read_text()) for d in ('calibration', 'paid', 'censored-calibration-16384', 'saturated-calibration-plain') for p in (BASE / d).glob('*/proof-store/*.json')}
    development = {p.name: {'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size} for p in BASE.glob('*.log')}
    saturated = json.loads((BASE/'saturated-calibration-plain/records.json').read_text())
    censored = json.loads((BASE/'censored-calibration-16384/records.json').read_text())
    ledger = {'saturatedPlainCalibrationRecords':saturated,'saturatedPlainCalibrationFrozenPlan':json.loads((BASE/'saturated-calibration-plain/frozen-plan.json').read_text()),'legacySnapshotPath':'pretransition-snapshot','calibrationSourcePlan':json.loads((BASE/'calibration/frozen-source-plan.json').read_text()),'calibrationToConfirmatoryPolicyParity':json.loads((BASE/'calibration-to-confirmatory-policy-parity.json').read_text()),'censoredCalibrationRecords':censored,'censoredCalibrationFrozenPlan':json.loads((BASE/'censored-calibration-16384/frozen-plan.json').read_text()),'archivedPathRemap':{'calibration/':'censored-calibration-16384/'},'requests':requests,'admittedProofAuditExports':proofs,'prepaidDevelopmentLogs':development,'inputReservationBackcheck':json.loads((BASE/'input-reservation-backcheck.json').read_text()), 'schema': 'ascent.factor-total-budget-ledger.v1', 'frozenPlan': plan, 'qualification': json.loads((BASE / 'qualification.json').read_text()), 'calibrationRecords': cal, 'confirmatoryRecords': rows, 'responsesIncludingFailures': responses, 'rawArtifactHashes': raw, 'actualInvoiceUsd': None}
    save(DOC / 'factor-total-budget-ledger.json', ledger)
    report = {'schema': 'ascent.factor-total-budget-report.v1', 'frozenPlanSha256': sha((BASE / 'frozen-plan.json').read_bytes()), 'ledgerSha256': sha((DOC / 'factor-total-budget-ledger.json').read_bytes()), 'pairs': pairs, 'aggregate': aggregates, 'calibration': [{'case': r['case'], 'metrics': metrics(r), 'grade': r['grade']} for r in cal], 'matchedSharedToolReplies': shared, 'censoredCalibrationPhases':len(censored),'saturatedPlainCalibrationPhases':len(saturated),'totalObservedStudyTokensIncludingCensored':sum(r['observedTotalTokens'] for r in rows+cal+censored+saturated),'protocolViolations': [{'case': r['case'], 'arm': r['arm'], 'phase': r['phase'], 'failure': r['failure']} for r in rows + cal if r['failure'] in ('budget_protocol_violation', 'missing_usage_budget_unknown', 'inconsistent_total_usage', 'inconsistent_usage_breakdown')], 'allObservedPhaseTotalsWithinBudget': all((r['observedTotalTokens'] <= plan['totalTokenBudget'] for r in rows + cal)), 'totalBudgetIsCeilingNotIdenticalSpend': True, 'hiddenSemanticThinkingRepetitionMeasured': False, 'analysisSourceSha256':sha(Path(__file__).read_bytes()),'completeConfirmatoryPhases': len(rows), 'noInferenceFromStochasticArmDifferences': True}
    save(DOC / 'factor-total-budget-report.json', report)
    table = '\n'.join(('| ' + str(p['case']) + ' / ' + str(p['phase']) + ' | ' + ('—' if p['fresh']['objectiveGap'] is None else str(p['fresh']['objectiveGap'])) + ' | ' + ('—' if p['retained']['objectiveGap'] is None else str(p['retained']['objectiveGap'])) + ' | ' + str(p['fresh']['totalTokens']) + ' / ' + str(p['retained']['totalTokens']) + ' | ' + str(p['fresh']['uniqueFeasibleSchedules']) + ' / ' + str(p['retained']['uniqueFeasibleSchedules']) + ' | ' + str(p['fresh']['maxProperPrefixDepth']) + ' / ' + str(p['retained']['maxProperPrefixDepth']) + ' |' for p in pairs))
    f = aggregates['fresh']
    t = aggregates['retained']
    text = f"""# Matched-evidence, total-budget native cache pilot

This pilot did not establish reduced thinking, deeper exploration or better quality from retained cache state. Fresh submitted {f['submitted']}/4 schedules and used {f['totalTokens']:,} gross tokens; retained submitted {t['submitted']}/4 and used {t['totalTokens']:,}. Native proof-packet construction occurred {f['freshNativePacketSolves']} versus {t['freshNativePacketSolves']} times. Aggregate native packet roundtrip time did not improve. These are descriptive small-sample outcomes, not causal degradation or improvement claims.

Both arms receive byte-identical initial Fact/derivation packets. Confirmatory study: {len(rows)} phases, four task/goal pairs, 14 and 16 jobs with immutable adjacent-pair transition penalties; independent exact direct-edge subset-plus-last DP grader frozen before paid calibration or confirmatory calls. No model grader, hidden-optimum feedback, full-answer cache, retries or failed-trial deletion.

All phases share the 98,304 gross-token ceiling: every input and every output, including thinking. Replayed history and provider prefix-cache hits count as full input. Reasoning is a subset of output and is not added twice. This is a common ceiling, not artificially equal realized spend. Before requests the controller conservatively reserves compact UTF-8 request bytes plus framing allowances. This is an empirical allowance, not a guaranteed exact tokenizer. Returned provider usage decides admission; any reserve violation, budget overshoot or unknown usage is a protocol failure. [DeepSeek identifies returned usage as authoritative](https://api-docs.deepseek.com/quick_start/token_usage/).

Each task minimizes weighted completion cost plus fixed adjacent-pair penalties. Penalties do not change completion times. The source precedence graph, durations and penalty matrix remain fixed while weights change between history-reset phases. The admitted Fact/derivation packet certifies precedence; the matrix is frozen task data, not an ASCENT arithmetic proof. The independent grader checks the entire composite objective.

A common controller allows two high-reasoning construction/refinement calls and then a forced non-thinking `submit` of the best already evaluated candidate. This finalizer never sees the hidden optimum. Its feedback and input tokens are charged normally. This finalizer is reached only if earlier response calls complete and input reservation allows another call; a censored refinement stops the phase and leaves the best candidate available for the any-time grade, without claiming successful completion. This is a common search policy, not a cache-arm advantage. [DeepSeek supports non-thinking effort and named tool choice](https://api-docs.deepseek.com/api/create-response/).

## Results

| Task / goal phase | Fresh objective gap | Retained objective gap | Gross tokens F / R | Unique feasible schedules F / R | Proper-prefix depth F / R |
| --- | ---: | ---: | ---: | ---: | ---: |
{table}

Fresh: {f['submitted']}/4 submitted, {f['optimal']}/4 optimal observed candidates ({f['submittedOptimal']} successfully submitted), {f['failures']} failed/censored phases. Retained: {t['submitted']}/4 submitted, {t['optimal']}/4 optimal observed candidates ({t['submittedOptimal']} successfully submitted), {t['failures']} failed/censored phases. Objective gaps use the submitted schedule; if none was submitted, the best evaluated candidate is separately labeled by the submission/failure fields. Invalid or absent candidates retain null gaps. Non-optimal submitted outcomes remain quality negatives even when their protocol completed.

Fresh gross tokens: {f['totalTokens']}; retained: {t['totalTokens']}. Reasoning tokens: {f['reasoningTokens']} / {t['reasoningTokens']}. Packet-covered Fact requests: {f['factorChecksAlreadyCoveredByPacket']} / {t['factorChecksAlreadyCoveredByPacket']}; duplicate requests within a phase: {f['duplicateFactRequests']} / {t['duplicateFactRequests']}. Unique feasible schedules: {f['uniqueFeasibleSchedules']} / {t['uniqueFeasibleSchedules']}. Branching prefix parents: {f['branchedPrefixParents']} / {t['branchedPrefixParents']}.

Native packet/factor roundtrip time: {f['nativePacketAndFactorSeconds']:.4f}s / {t['nativePacketAndFactorSeconds']:.4f}s. Fresh shared-packet solves: {f['freshNativePacketSolves']} / {t['freshNativePacketSolves']}; retained shared-packet lookups: {f['retainedNativePacketLookups']} / {t['retainedNativePacketLookups']}. Fresh native Fact solves: {f['freshNativeFactorSolves']} / {t['freshNativeFactorSolves']}; retained Fact lookups: {f['retainedNativeFactorLookups']} / {t['retainedNativeFactorLookups']}. Audit proof bytes written: {f['proofBytesWritten']} / {t['proofBytesWritten']}. Time includes native IPC, checking and certificate export. Individual Fact-tool proof writes are included in per-tool costs. Process startup and shared-packet Python proof-file writes are not separately timed; these timings are not an end-to-end native speed claim. Grading time is recorded separately, outside model-visible inference.

## Evidence boundaries

Means of quality over valid candidates exclude missing candidates and must not be read as arm-level improvement: retained has more missing results. Use paired gaps together with validity, submission and censoring. Same source, goal, initial-question bytes, evidence hash and deterministic tool-reply policy apply within each pair. {shared} shared requested tool replies were compared for exact equality. Cache flags, timings and native provenance receipts never enter model input. Later model histories can diverge because sampling is stochastic; backend identity and seed determinism are unavailable. The counterbalanced two-task sample supports descriptive comparisons, not a significance claim or a stable model-level causal speedup.

With identical visible evidence, retained native state directly avoids external recomputation. It supplies no extra model information or token-allocation instruction relative to fresh. Differences in reasoning tokens, schedules or quality cannot establish a causal reduction in repeated internal thinking. Observable repeated Fact/tool/path checks are operational proxies; Semantic repetition in the returned reasoning text is not annotated or measured; unexposed internal states are unavailable. Prefix length alone is not proof of deeper reasoning: proper-prefix depth, distinct feasible candidates and prefix branching are reported separately. No finding of model-level efficiency or quality improvement is inferred from native-cache savings alone. This cache certifies precedence factors; it does not memoize the arithmetic of weighted completion/transition costs or prove optimality. Repeated tool signatures do not identify semantic overlap among different reasoning paths.

An initial separately frozen calibration exhausted both 16,384 output allowances entirely in thinking: no tool calls, no candidate schedules, hardness gate failed. Those two censored paid phases remain under `censored-calibration-16384/` and in the ledger; they are not pooled into the revised calibration or confirmatory rates. The revised protocol keeps the same 98,304 gross-token ceiling, tasks and grader, raises the per-call output cap to 32,768, and asks for an initial feasible candidate before refinement plus explicit alternative branch probes.

The v2 plain weighted-completion calibration then found optimal candidates in both tasks (despite 164,370 and 212,214,720 feasible schedules), followed by censored further thinking without submission. It also failed the predeclared non-optimal-quality gate. Those stages are under `saturated-calibration-plain/`; the former native artifacts remain byte-preserved in `pretransition-snapshot/`. They are not pooled into confirmatory quality rates. The v3 task adds fixed transition penalties and freezes the exact subset-plus-last grader, initial-candidate policy and bounded finalization before new calibration.

Disjoint calibration tasks and all their paid outcomes are preserved in the ledger. The v3 task definitions, model request policy and grader were frozen before transition calibration. After calibration, before any confirmatory outcome, v4 froze any-time candidate quality as the primary endpoint and kept submission/censoring as separate failures. Eighteen task, artifact and model-policy fields match exactly between v3 and v4; only admission/metadata changed. The stricter original calibration gate and controller are retained separately. No calibration censoring was reclassified as success. The hardness gate required at least one valid non-optimal best-observed calibration candidate with known in-budget usage; confirmatory failures and outcomes were never used to choose tasks. Exact graders qualify against ten seven-job exhaustive-enumeration controls, hand-computed three-job optima with and without transition penalties, invalid schedules and their own recovered exact witnesses. This is finite experimental qualification, not a Lean proof of the new DP implementation.

The new bridge and grader are compiled against the prior frozen production kernel, whose candidate source files match the current checkout. All inherited compiler artifacts and new executable bytes are bound in the plan; this is not a new whole-repository build at `{plan['headAtFreeze']}`. Prior proof/Lean/Quint correspondence remains scoped to the old bounded retained-evidence checks. Stored certificates are audit exports; retained lookup uses admitted in-memory native receipts, not replay/re-admission from disk.

The retained 16-job transfer phase stopped with 50,431 observed gross tokens because conservative reservation would reject another request. This is an estimate-driven stop, not proof that the actual 98,304-token ceiling was exhausted. The guard is deliberately conservative and can underuse the available budget. Both arms use the same guard; this pilot cannot claim that the entire common allowance was spent on productive exploration.

## Reproduction and retained failures

Frozen plan, qualification, native build failures, complete requests, SSE traces, responses and per-phase receipts remain under `.cache/ascent/factor-budget/`. The portable ledger retains every calibration and confirmatory phase, all returned provider responses including failures, exact usage and every raw-file hash. Secrets and authorization headers are never recorded. No invoice dollar amount is inferred. The original pilot and its censored round are unchanged.

Commands: `PYTHONPATH=workbench/src:python/src python3 -m agentic_ai_lab_testing.assessment_studies.factor_budget qualify`, then `freeze`, `calibrate`, `run`, and `python3 -m agentic_ai_lab_testing.assessment_studies.factor_budget_report`. Paid directories are exclusive: rerunning never overwrites an existing trial. Hash checks bind the frozen controller, grader, qualification and native artifacts before and after each run.
"""
    (DOC / 'factor-total-budget-report.md').write_text(text)
    print(json.dumps(report['aggregate'], indent=2))
    print('MATCHED-REPORT-OK pairs=', len(pairs))
if __name__ == '__main__':
    main()
