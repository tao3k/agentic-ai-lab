# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Auditable repository study statistics; censored work is never a savings win."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price
from .repository_metrics import trajectory_metrics, integrated_metrics, metric_report


def repair_effort(attempts):
    start = None
    kind = None
    for index, attempt in enumerate(attempts):
        for action in attempt['actions']:
            result = action.get('result')
            if not isinstance(result, dict): continue
            rejected = action['name'] in ('submit_patch', 'implicit_submit') and result.get('verified') is False
            failed_controls = action['name'] == 'run_checks' and result.get('allChecksPassed') is False
            if rejected or failed_controls:
                start = index; kind = action['name']; break
        if start is not None: break
    if start is None: return {'failedCandidateDetected': False, 'observedReasoningTokens': 0, 'modelCalls': 0, 'peakDollarEstimate': 0}
    effort = until_verified(attempts[start:])
    selected = attempts[start:start+effort['attempts']]
    dollars = sum(price(a['usage']) for a in selected) if effort['modelUsageComplete'] else None
    return {'failedCandidateDetected': True, 'firstFailureFeedbackTurn': attempts[start].get('turn', start+1), 'failureFeedbackKind': kind, 'peakDollarEstimate': dollars, **effort}


def billing(directory):
    totals = Counter(); artifacts = {}; unknown = []
    requests = sorted(directory.glob('*/*.request.json'))
    for request in requests:
        response = request.with_name(request.name.replace('.request.json', '.response.json'))
        if not response.exists(): unknown.append(str(request.relative_to(directory))); continue
        data = json.loads(response.read_text()); terminal = data.get('terminal') or {}; usage = terminal.get('usage')
        artifacts[str(response.relative_to(directory))] = hashlib.sha256(response.read_bytes()).hexdigest()
        if not usage: unknown.append(str(request.relative_to(directory))); continue
        totals['observedCalls'] += 1
        totals['inputTokens'] += usage['input_tokens']
        totals['outputIncludingReasoningTokens'] += usage['output_tokens']
        thinking = usage.get('output_tokens_details', {}).get('reasoning_tokens')
        if thinking is None: totals['thinkingUsageMissing'] += 1
        else: totals['observedReasoningTokens'] += thinking
        totals['peakDollarEstimate'] += price(usage)
    return {'startedRequests': len(requests), **dict(totals), 'unknownUsageRequests': unknown, 'responseHashes': artifacts, 'offPeakDollarEstimate': totals['peakDollarEstimate'] / 2, 'invoiceVerified': False}


def records(directory):
    if not directory.exists(): return []
    return [{**json.loads(path.read_text()), 'episodeReceipt': str(path),
             'episodeSha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in sorted(directory.glob('*/episode.json'))]


def summarize(primary, continuation, invalid, recovery=None):
    original = records(primary); extensions = records(continuation)
    combined = {(r['task'], r['repetition'], r['arm']): r for r in original}
    combined.update({(r['task'], r['repetition'], r['arm']): r for r in extensions})
    if recovery is not None:
        combined.update({(r['task'], r['repetition'], r['arm']): r for r in records(recovery/'continued')})
    entries = []
    for key, record in sorted(combined.items()):
        journal = record.get('evidenceJournal', [])
        entries.append({'task': key[0], 'repetition': key[1], 'arm': key[2], 'status': record['status'], 'episodeReceipt': record['episodeReceipt'], 'episodeSha256': record['episodeSha256'], 'effort': until_verified(record['attempts']), 'repairEffort': repair_effort(record['attempts']), 'checkedEvidenceQueries': len(journal), 'reusedComponents': sum(len(x['reusedComponents']) for x in journal), 'freshComponents': sum(len(x['freshComponents']) for x in journal), 'checkedEvidenceSeconds': sum(x['seconds'] for x in journal), 'sourceGenerations': sorted({x['generation'] for x in journal}), 'reconstructionQueries': len(record.get('reconstructionJournal', [])), 'trajectory': trajectory_metrics(record['attempts'])})
    pairs = []
    for row in entries:
        if row['arm'] == 'ordinary-tools': continue
        baseline = next(x for x in entries if (x['task'], x['repetition'], x['arm']) == (row['task'], row['repetition'], 'ordinary-tools'))
        reduction = paired_reduction(baseline['effort'], row['effort'], 'observedReasoningTokens')
        pairs.append({'task': row['task'], 'repetition': row['repetition'], 'arm': row['arm'], 'thinkingReduction': reduction, 'baselineThinking': baseline['effort']['observedReasoningTokens'], 'candidateThinking': row['effort']['observedReasoningTokens'], 'baselineVerified': baseline['effort']['verified'], 'candidateVerified': row['effort']['verified'], 'baselineCalls': baseline['effort']['modelCalls'], 'candidateCalls': row['effort']['modelCalls']})
    return {'schema': 'ascent.repository-statistics.v2', 'primaryEpisodes': [{'task': r['task'], 'repetition': r['repetition'], 'arm': r['arm'], 'status': r['status'], 'effort': until_verified(r['attempts'])} for r in original], 'episodes': entries, 'pairs': pairs, 'integratedMetrics': integrated_metrics(entries, pairs), 'billing': {'invalidExecution': billing(invalid), 'primary': billing(primary), 'continuation': billing(continuation), **({'responsePreservingRecovery': billing(recovery/'continued')} if recovery is not None else {})}, 'complete': ((recovery if recovery is not None else continuation) / 'result.json').exists() and json.loads(((recovery if recovery is not None else continuation) / 'result.json').read_text()).get('complete', False)}


def report(data, plan):
    lines = ['<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->', '<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->', '', '# Real Repository Reasoning Experiment', '', '## Objective and experiment status', '', 'Measure cumulative provider-reported thinking tokens until the first independently accepted implementation, including source exploration, rejected changes, failed submissions and repair. Visible answer length is not the savings denominator.', '', f"Status: **{'completed' if data['complete'] else 'running; results below are interim'}**. Two source-qualified tasks, three conditions, two repetitions: 12 trajectories. The frozen primary budget was 10 turns. Every unfinished primary trajectory is eligible for the same adaptive continuation to 40 cumulative turns. Primary and adaptive outcomes are reported separately. Prior history, opaque provider reasoning, patches and token charges are retained.", '', '## Complete task statements', '']
    for case in plan['tasks']:
        lines += [f"### {case['name']}", '', case['question'], '', f"Editable implementation: {', '.join(case['editable'])}.", '']
    lines += ['## Task quality and complexity audit', '',
              'The [task quality audit](repository-task-quality.md) maps each source defect to its interacting obligations, selected grader evidence, blind spots and actual Scheme mechanism coverage. These are real, reproducible, localized algorithmic repairs; high difficulty is not calibrated. Twelve trajectories represent two independent problems. The review is retrospective and does not change the frozen questions or grading. Current Scheme support checks syntax, not the domain invariants needed to establish semantic reasoning enhancement.', '']
    lines += ['## Design and independent acceptance', '', 'Sources: [NetworkX PR 8931](https://github.com/networkx/networkx/pull/8931), first public disclosure September 27, 2026; [SymPy issue 30698](https://github.com/sympy/sympy/issues/30698), first public disclosure October 8, 2026. Exact source/grader/environment hashes are bound in the source audit and frozen plan. Recent disclosure does not prove absence from training or retrieval.', '', 'The model sees the complete problem, parent source, automatic source/edit/execution tools and development controls. It does not receive the solution diff, fixed implementation, hidden assertions or git/network access. Output ceiling: 131,072 tokens; high reasoning effort; automatic tool choice. The requested backend alias is `deepseek-flash`; the returned alias does not attest an immutable model revision.', '', 'Ordinary tools expose source and execution observations. Scheme fresh and Scheme retained additionally expose identical least-fixed-point support over local syntactic references. Only retained evidence persists across queries. Because fresh and retained return identical facts and complete model history, cache persistence alone has no designed mechanism to reduce model thinking; their token differences are stochastic observations, not causal evidence of a cache-driven thinking benefit. Compare either Scheme condition with ordinary tools for the syntactic-support intervention, and fresh versus retained for checker reuse. Source-byte changes invalidate evidence. This is checked syntactic support, not proof of Python execution or a general semantic evidence engine. Continuation reconstructs source/evidence state from original tool actions; reconstruction work is separate, and no historical model or test requests are repeated.', '', 'Acceptance requires exact hidden test identities, exit zero and all cases passing: 24 NetworkX cases and 3 SymPy cases. Qualification had 2 failing and 22 passing NetworkX cases, and 2 failing and 1 passing SymPy cases. These 27 selected cases do not constitute full upstream CI. The tool adapter restricts edits and import changes; this is a bounded repair pilot.', '', '## Primary 10-turn outcomes', '', '| Condition | Verified / trajectories | Thinking tokens consumed, including censored work |', '| --- | ---: | ---: |']
    for arm in plan['arms']:
        rows = [r for r in data['primaryEpisodes'] if r['arm'] == arm]
        lines.append(f"| {arm} | {sum(r['effort']['verified'] for r in rows)}/{len(rows)} | {sum(r['effort']['observedReasoningTokens'] for r in rows):,} |")
    lines += ['', '## Cumulative outcomes including uniform continuation', '', '| Task | Rep | Condition | Status | Calls | Thinking tokens | Repair thinking / peak USD | Evidence queries / reused components |', '| --- | ---: | --- | --- | ---: | ---: | ---: | ---: |']
    for r in data['episodes']:
        lines.append(f"| {r['task']} | {r['repetition']+1} | {r['arm']} | {r['status']} | {r['effort']['modelCalls']} | {r['effort']['observedReasoningTokens']:,} | {r['repairEffort']['observedReasoningTokens']:,} / {format(r['repairEffort']['peakDollarEstimate'], '.6f') if r['repairEffort']['peakDollarEstimate'] is not None else 'unknown'} | {r['checkedEvidenceQueries']} / {r['reusedComponents']} |")
    lines += ['', '| Condition | Independently verified / trajectories | Total thinking consumed including censored work |', '| --- | ---: | ---: |']
    for arm in plan['arms']:
        rows = [r for r in data['episodes'] if r['arm'] == arm]
        lines.append(f"| {arm} | {sum(r['effort']['verified'] for r in rows)}/{len(rows)} | {sum(r['effort']['observedReasoningTokens'] for r in rows):,} |")
    lines += ['', 'Repair work starts at the first failing development check or independently rejected submission and includes that provider turn through acceptance or censoring. Provider usage cannot be apportioned among individual actions within one turn. Source-edit rejections and diagnostic calls are still charged in total effort. Zero repair thinking means no failing validation feedback was observed before termination; it does not mean a censored trajectory did no wasted work.', '', '## Paired thinking reductions', '']
    for arm in plan['arms'][1:]:
        pairs = [p for p in data['pairs'] if p['arm'] == arm and p['thinkingReduction'] is not None]
        denominator = sum(p['baselineThinking'] for p in pairs)
        estimate = f"{100*(1-sum(p['candidateThinking'] for p in pairs)/denominator):.2f}%" if denominator else 'not estimable'
        lines.append(f"- {arm}: {len(pairs)} jointly accepted pairs; token-weighted reduction **{estimate}**. Censored trajectories are excluded from this ratio and remain visible above.")
    lines += ['', '### Integrated outcome', '']
    for arm in plan['arms']:
        rows = [r for r in data['episodes'] if r['arm'] == arm]
        lines.append(f"- {arm}: {sum(r['effort']['verified'] for r in rows)}/{len(rows)} independently verified; {sum(r['effort']['modelCalls'] for r in rows)} cumulative calls; {sum(r['effort']['observedReasoningTokens'] for r in rows):,} thinking tokens including censored work.")
    lines += ['', 'The retained condition must not be promoted as a stable 40–50% improvement: its jointly accepted-pair ratio omits visibly censored trajectories, and its acceptance rate must be considered alongside that ratio. This pilot validates an executable measurement path and real checked-component reuse, with mixed quality and thinking outcomes.', '', '### Mechanism reflection', '', 'The current Scheme intervention checks syntactic dependency closure. It does not encode the domain invariants that determine matrix-update correctness or leading-exponent precision. Consequently, cache reuse is real checker work reuse but does not establish semantic enhancement of model thinking. The next integrated intervention needs source-qualified executable observations and domain claims checked by the appropriate Scheme or external checker, explicit invalidation when premises change, and a new independent matched corpus. The model should continue reasoning about the complete problem; a mandatory subproblem-first workflow would change the hypothesis. Lean/Quint must model the observation and invalidation contract, rather than certify arbitrary model reasoning text.']
    lines += ['', '## Research expense and execution fault', '', '| Category | Started requests | Responses with usage | Thinking tokens | Peak USD estimate | Off-peak USD estimate | Unknown usage |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for label, b in data['billing'].items():
        lines.append(f"| {label} | {b['startedRequests']} | {b.get('observedCalls',0)} | {b.get('observedReasoningTokens',0):,} | {b.get('peakDollarEstimate',0):.6f} | {b['offPeakDollarEstimate']:.6f} | {len(b['unknownUsageRequests'])} |")
    known_peak = sum(b.get('peakDollarEstimate', 0) for b in data['billing'].values())
    unknown = sum(len(b['unknownUsageRequests']) for b in data['billing'].values())
    lines += ['', f"Known research expense: **${known_peak:.6f} at peak rates / ${known_peak/2:.6f} at off-peak rates**, plus {unknown} request(s) without final usage. No unknown charge is treated as zero."]
    lines += ['', 'The initial paid run had a local relative-path defect: the child changed its working directory and could not find its sandbox profile. Those calls are research expense, excluded from model accuracy and savings claims. One interrupted request has no final usage receipt; its charge is unknown, not zero. Paths are now normalized and execution failures stop further paid calls. Separately, the embedded Gambit SIGCHLD handler could reap Python-owned child exit statuses; restoring Python ownership is covered by a regression requiring exits 7, 0 and 9 to survive engine initialization. Near the end of continuation, an idle worker queue raised BlockingIOError and broke the process pool. A separate diagnosis reproduced runtime changes to standard descriptor flags, including nonblocking mode; host descriptor flags are now preserved around C ABI calls, and future workers run one trajectory each. The last fully receipted response was recovered without another paid request, its missing tool output completed, and its full history continued serially for `series-root-precision`, repetition 2, `scheme-retained`. The recovery manifest explicitly binds the infrastructure changes; original receipts remain unchanged. Descriptor changes are observed; the complete internal causal path to the queue failure is not formally established.', '', 'Estimates use reported cached input and output including thinking. [Official DeepSeek pricing](https://api-docs.deepseek.com/quick_start/pricing/) lists peak rates of $0.30/M uncached input, $0.006/M cached input and $1.20/M output, with off-peak rates half as large. These are tariff estimates, not verified account debits. Total research expense includes all categories and any unknown charge remains unresolved.', '', '## Interpretation and remaining scope', '', 'No 40–50% improvement is asserted without jointly accepted comparisons. Two tasks and two repetitions per condition cannot establish broad four-family performance or statistical significance. Source restrictions, partial syntactic extraction and selected grader coverage limit generalization. Exact-repeat zero-call reuse is a separate experiment and is not included in first-solution improvement. Existing Lean/Quint retention results do not prove this collector, Python extractor or evaluator isolation; no new formal closure is claimed.', '', 'The source-selection protocol follows [SWE-rebench](https://arxiv.org/html/2505.20411v2), [SWE-rebench V2](https://arxiv.org/html/2602.23866v2) and [LiveCodeBench](https://arxiv.org/abs/2403.07974): fresh provenance, executable failure-to-pass qualification, hidden grading and repeated trajectories. Negative results and local infrastructure faults remain part of the record.', '']
    lines += metric_report(data)
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('plan', 'primary', 'continuation', 'invalid', 'destination'): parser.add_argument(name, type=Path)
    parser.add_argument('--recovery', type=Path)
    args = parser.parse_args(); data = summarize(args.primary, args.continuation, args.invalid, args.recovery)
    data['statisticsProducerHashes'] = {name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
                                      for name in ('repository_statistics.py', 'repository_metrics.py', 'inference_effort.py', 'inference_reuse_study.py')}
    data['frozenPlanSha256'] = hashlib.sha256((args.plan/'plan.json').read_bytes()).hexdigest()
    data['primaryResultSha256'] = hashlib.sha256((args.primary/'result.json').read_bytes()).hexdigest()
    data['originalProducerHashes'] = json.loads((args.plan/'plan.json').read_text())['producerHashes']
    if args.recovery is not None:
        data['recoveryPlanSha256'] = hashlib.sha256((args.recovery/'plan.json').read_bytes()).hexdigest()
        data['recoveryProducerHashes'] = json.loads((args.recovery/'plan.json').read_text())['recoveryProducerHashes']
        data['recoveryResultSha256'] = hashlib.sha256((args.recovery/'result.json').read_bytes()).hexdigest() if (args.recovery/'result.json').exists() else None
    args.destination.with_suffix('.json').write_text(json.dumps(data, indent=2) + '\n')
    args.destination.write_text(report(data, json.loads((args.plan / 'plan.json').read_text())))
    print('REPOSITORY-STATISTICS', 'complete=' + str(data['complete']), 'trajectories=' + str(len(data['episodes'])))
