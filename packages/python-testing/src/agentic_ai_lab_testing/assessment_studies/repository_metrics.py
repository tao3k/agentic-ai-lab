# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Receipt-only trajectory metrics; never inspect provider reasoning text."""
from collections import Counter
from statistics import mean, median, stdev

from .inference_effort import until_verified
from .inference_reuse_study import price


def distribution(values):
    if not values:
        return {'n': 0, 'mean': None, 'median': None, 'min': None, 'max': None, 'sampleSd': None}
    return {'n': len(values), 'mean': mean(values), 'median': median(values),
            'min': min(values), 'max': max(values),
            'sampleSd': stdev(values) if len(values) > 1 else None}


def trajectory_metrics(attempts, primary_turns=10):
    """Use accepted-prefix receipts, with missing token usage propagated as null.

    Actions describe observations, not where a model spent its thinking. Phase
    splits are whole-turn accounting, never inferred from private reasoning.
    """
    selected = attempts[:until_verified(attempts)['attempts']]
    rounds = []; totals = Counter(); cumulative = 0; complete = True
    first_edit = None; first_validation = None; source_ids = []
    for index, attempt in enumerate(selected, 1):
        usage = attempt.get('usage')
        calls = attempt['providerCalls']
        thinking = (usage.get('output_tokens_details', {}).get('reasoning_tokens')
                    if calls and usage else (0 if not calls else None))
        complete &= thinking is not None
        if thinking is not None: cumulative += thinking
        dollars = price(usage) if calls and usage else (0 if not calls else None)
        input_tokens = usage['input_tokens'] if calls and usage else (0 if not calls else None)
        output_tokens = usage['output_tokens'] if calls and usage else (0 if not calls else None)
        cached = usage.get('input_tokens_details', {}).get('cached_tokens') if calls and usage else (0 if not calls else None)
        actions = []
        for action in attempt['actions']:
            name = action['name']; totals[name] += 1
            result = action.get('result')
            row = {'name': name}
            if isinstance(result, dict):
                # Explicit allowlist excludes source, prompts, outputs and reasoning.
                for key in ('edited', 'priorEvidenceInvalidated', 'exitCode', 'verified',
                            'allChecksPassed', 'counts', 'seconds', 'sourceIdentity'):
                    if key in result: row[key] = result[key]
                row['rejected'] = 'error' in result
                if isinstance(result.get('verifiedCandidate'), dict):
                    row['verified'] = True
                    row['sealedSourceIdentity'] = result['verifiedCandidate']['sourceIdentity']
                checks = result.get('auditDomainChecks')
                if checks is not None:
                    row['assessedDomainClaims'] = sum(len(c['claims']) for c in checks)
                    row['failedDomainClaims'] = sum(not flag for c in checks for _, flag in c['claims'])
                if row['rejected']: totals['toolRejections'] += 1
                if name in ('edit_source','implicit_edit') and result.get('edited'):
                    totals['acceptedEdits'] += 1
                    if first_edit is None: first_edit = index
                if name in ('run_checks', 'submit_patch', 'implicit_submit'):
                    if first_validation is None: first_validation = index
                    if result.get('allChecksPassed') is True: totals['passingValidations'] += 1
                    if result.get('allChecksPassed') is False: totals['failingValidations'] += 1
                    if name in ('submit_patch', 'implicit_submit') and result.get('verified') is False:
                        totals['rejectedSubmissions'] += 1
            actions.append(row)
        identity = attempt.get('sourceIdentity')
        if identity is not None and (not source_ids or identity != source_ids[-1]): source_ids.append(identity)
        rounds.append({'turn': attempt.get('turn', index), 'position': index,
                       'phase': 'primary' if index <= primary_turns else 'adaptive',
                       'calls': calls, 'thinkingTokens': thinking,
                       'cumulativeThinkingTokens': cumulative if complete else None,
                       'inputTokens': input_tokens, 'cachedInputTokens': cached,
                       'outputIncludingThinkingTokens': output_tokens,
                       'peakDollarEstimate': dollars,
                       'providerSeconds': attempt.get('providerSeconds'),
                       'sourceIdentity': identity, 'accepted': bool(attempt['correct']),
                       'independentCandidateChecks': [{k:g[k] for k in ('verified','sourceIdentity','exitCode','counts','seconds') if k in g}
                                                     for g in attempt.get('candidateChecks',[])],
                       'actions': actions})
    def phase_tokens(rows):
        return sum(r['thinkingTokens'] for r in rows) if all(r['thinkingTokens'] is not None for r in rows) else None
    # The first edit turn belongs to the post-edit phase; multiple actions share usage.
    boundary = first_edit - 1 if first_edit is not None else len(rounds)
    return {'rounds': rounds, 'actionCounts': dict(totals),
            'firstAcceptedEditTurn': first_edit, 'firstValidationTurn': first_validation,
            'firstAcceptedTurn': next((r['turn'] for r in rounds if r['accepted']), None),
            'preEditThinkingTokens': phase_tokens(rounds[:boundary]),
            'fromFirstEditThinkingTokens': phase_tokens(rounds[boundary:]),
            'primaryThinkingTokens': phase_tokens(rounds[:primary_turns]),
            'adaptiveThinkingTokens': phase_tokens(rounds[primary_turns:]),
            'observedSourceTransitions': max(0, len(source_ids)-1),
            'distinctSourceIdentities': len(set(source_ids)),
            'thinkingPerTurn': distribution([r['thinkingTokens'] for r in rounds if r['thinkingTokens'] is not None]),
            'peakDollarEstimate': sum(r['peakDollarEstimate'] for r in rounds) if all(r['peakDollarEstimate'] is not None for r in rounds) else None,
            'providerSeconds': sum(r['providerSeconds'] for r in rounds) if all(r['providerSeconds'] is not None for r in rounds) else None}


def integrated_metrics(entries, pairs):
    summaries = []
    for arm in sorted({r['arm'] for r in entries}):
        rows = [r for r in entries if r['arm'] == arm]
        accepted = [r for r in rows if r['effort']['verified']]
        censored = [r for r in rows if not r['effort']['verified']]
        thinking_complete = all(r['effort']['reasoningUsageComplete'] for r in rows)
        total = sum(r['effort']['observedReasoningTokens'] for r in rows) if thinking_complete else None
        ps = [p for p in pairs if p['arm'] == arm and p['thinkingReduction'] is not None]
        base = sum(p['baselineThinking'] for p in ps)
        saved = sum(p['baselineThinking'] - p['candidateThinking'] for p in ps)
        turns = [t for r in rows for t in r['trajectory']['rounds']]
        def total_field(key):
            values = [t[key] for t in turns]
            return sum(values) if all(v is not None for v in values) else None
        input_total = total_field('inputTokens'); cached_total = total_field('cachedInputTokens')
        summaries.append({'arm': arm, 'trajectories': len(rows), 'accepted': len(accepted),
                          'acceptanceRate': len(accepted)/len(rows),
                          'thinkingIncludingCensored': total,
                          'censoredThinking': sum(r['effort']['observedReasoningTokens'] for r in censored) if all(r['effort']['reasoningUsageComplete'] for r in censored) else None,
                          'thinkingPerAcceptedYield': total/len(accepted) if accepted and total is not None else None,
                          'calls': sum(r['effort']['modelCalls'] for r in rows),
                          'inputTokens': input_total, 'cachedInputTokens': cached_total,
                          'cachedInputFraction': cached_total/input_total if input_total and cached_total is not None else None,
                          'outputIncludingThinkingTokens': total_field('outputIncludingThinkingTokens'),
                          'peakDollarEstimate': total_field('peakDollarEstimate'),
                          'summedProviderSeconds': total_field('providerSeconds'),
                          'thinkingDistributionAll': distribution([r['effort']['observedReasoningTokens'] for r in rows if r['effort']['reasoningUsageComplete']]),
                          'callsDistributionAccepted': distribution([r['effort']['modelCalls'] for r in accepted]),
                          'jointlyAcceptedPairs': len(ps), 'pairedSavedThinking': saved,
                          'pairedWeightedReduction': saved/base if base else None,
                          'pairedReductionDistribution': distribution([p['thinkingReduction'] for p in ps]),
                          'pairedWins': sum(p['thinkingReduction'] > 0 for p in ps),
                          'pairedRegressions': sum(p['thinkingReduction'] < 0 for p in ps),
                          'pairedTies': sum(p['thinkingReduction'] == 0 for p in ps),
                          'milestones': [{'turnBudget': k, 'accepted': sum(r['effort']['verified'] and r['effort']['firstVerifiedAttempt'] <= k for r in rows),
                                          'thinkingConsumed': sum(sum(t['thinkingTokens'] for t in r['trajectory']['rounds'][:k]) for r in rows) if thinking_complete else None}
                                         for k in (10, 20, 30, 40)]})
    return summaries


def metric_report(data):
    lines = ['', '## Detailed metric definitions and quality-cost accounting', '',
             '- Primary target: cumulative provider thinking tokens to first independent acceptance. An unfinished trajectory is right-censored at its final turn; its consumed tokens remain real expense.',
             '- Paired reduction = (baseline thinking − candidate thinking) / baseline thinking, only with both accepted and complete thinking usage. Weighted reduction divides summed absolute savings by summed baseline tokens on exactly those pairs.',
             '- Portfolio thinking per accepted yield = ALL consumed thinking, including censored work, / number accepted. This is a descriptive resource-yield ratio, not a prediction of retry cost, a per-question speedup or a paired savings claim.',
             '- Turn milestones show accepted counts and consumed thinking at common budgets. Calls after an earlier acceptance are not invented.',
             '- Pre-edit and from-first-edit partitions use whole provider turns; the first accepted edit turn belongs to the latter. Repair accounting overlaps these partitions and must not be added to them.',
             '- Development checks and independent grading are separate actions. An accepted edit means admission by the edit adapter, not a verified fix. Tool rejection does not establish semantic failure; a nonzero reproducer exit is not automatically a failed candidate.',
             '- Provider seconds are summed observed request durations, including network/service time. They do not measure internal thinking time or parallel experiment wall time. Scheme journal seconds measure checked-query work; reconstruction is separate.',
             '- Distributions are descriptive: four trajectories per arm and two tasks do not support population significance or a reliable confidence interval. No causal token attribution is inferred from actions.', '',
             '| Condition | Accepted | All thinking | Censored thinking | Thinking / accepted yield | All-trajectory median [min, max] |',
             '| --- | ---: | ---: | ---: | ---: | ---: |']
    def number(value): return 'unknown' if value is None else f'{value:,.0f}'
    for s in data['integratedMetrics']:
        d = s['thinkingDistributionAll']
        lines.append(f"| {s['arm']} | {s['accepted']}/{s['trajectories']} ({100*s['acceptanceRate']:.0f}%) | {number(s['thinkingIncludingCensored'])} | {number(s['censoredThinking'])} | {number(s['thinkingPerAcceptedYield'])} | {number(d['median'])} [{number(d['min'])}, {number(d['max'])}] |")
    lines += ['', '### Complete provider workload, including censored trajectories', '',
              '| Condition | Calls | Input / cached input tokens | Cached input fraction | Output incl. thinking | Peak USD estimate | Summed request seconds |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for s in data['integratedMetrics']:
        fraction = 'unknown' if s['cachedInputFraction'] is None else f"{100*s['cachedInputFraction']:.2f}%"
        dollars = 'unknown' if s['peakDollarEstimate'] is None else f"{s['peakDollarEstimate']:.6f}"
        lines.append(f"| {s['arm']} | {s['calls']} | {number(s['inputTokens'])} / {number(s['cachedInputTokens'])} | {fraction} | {number(s['outputIncludingThinkingTokens'])} | {dollars} | {number(s['summedProviderSeconds'])} |")
    lines += ['', 'Provider input-cache hits and Scheme checked-component reuse are different mechanisms. Cache discounts affect tariff estimates; they do not establish saved model thinking. Output totals include thinking and must not be added to thinking a second time. These costs exclude the separately itemized invalid infrastructure run.']
    lines += ['', '### Common-budget convergence', '', '| Condition | Turn budget | Independently accepted | Cumulative thinking consumed |', '| --- | ---: | ---: | ---: |']
    for s in data['integratedMetrics']:
        for m in s['milestones']:
            lines.append(f"| {s['arm']} | {m['turnBudget']} | {m['accepted']}/{s['trajectories']} | {number(m['thinkingConsumed'])} |")
    lines += ['', '### Every matched comparison', '', '| Task | Rep | Candidate | Acceptance: baseline / candidate | Thinking: baseline / candidate | Absolute thinking saved | Reduction | Calls: baseline / candidate |', '| --- | ---: | --- | --- | ---: | ---: | ---: | ---: |']
    for p in data['pairs']:
        ratio = p['thinkingReduction']
        saved = number(p['baselineThinking']-p['candidateThinking']) if ratio is not None else 'not estimable'
        reduction = f'{ratio*100:.2f}%' if ratio is not None else 'not estimable'
        lines.append(f"| {p['task']} | {p['repetition']+1} | {p['arm']} | {p['baselineVerified']} / {p['candidateVerified']} | {number(p['baselineThinking'])} / {number(p['candidateThinking'])} | {saved} | {reduction} | {p['baselineCalls']} / {p['candidateCalls']} |")
    lines += ['', '### Pair dispersion and eligibility', '']
    for s in data['integratedMetrics']:
        if s['arm'] == 'ordinary-tools': continue
        d = s['pairedReductionDistribution']
        fmt = lambda x: 'not estimable' if x is None else f'{100*x:.2f}%'
        lines.append(f"- {s['arm']}: {s['jointlyAcceptedPairs']}/{s['trajectories']} eligible pairs; wins/regressions/ties {s['pairedWins']}/{s['pairedRegressions']}/{s['pairedTies']}; absolute saved thinking {number(s['pairedSavedThinking'])}; weighted {fmt(s['pairedWeightedReduction'])}; unweighted mean {fmt(d['mean'])}, median {fmt(d['median'])}, range [{fmt(d['min'])}, {fmt(d['max'])}], sample SD {fmt(d['sampleSd'])}. SD describes this sample, not uncertainty over future tasks.")
    lines += ['', '## Complete question trajectories and per-turn usage ledger', '',
              'Each row is a provider turn, not necessarily one reasoning round or one candidate. Action flags and verifier counts are observed receipts. No private reasoning text, source snippets or model narrative is reproduced. Full source identities and action counts are in the JSON companion. Rounded displayed USD values do not change full-precision JSON totals.', '']
    for r in data['episodes']:
        t = r['trajectory']; counts = t['actionCounts']
        journal_seconds = r['checkedEvidenceSeconds']
        lines += [f"### {r['task']} / repetition {r['repetition']+1} / {r['arm']}", '',
                  f"Outcome: **{r['status']}**; first accepted turn: {t['firstAcceptedTurn']}; first accepted edit turn: {t['firstAcceptedEditTurn']}; first validation turn: {t['firstValidationTurn']}.", '',
                  f"Episode receipt: `{r['episodeReceipt']}`; SHA-256 `{r['episodeSha256']}`.", '',
                  f"Thinking partition: primary {number(t['primaryThinkingTokens'])}; adaptive {number(t['adaptiveThinkingTokens'])}; pre-edit {number(t['preEditThinkingTokens'])}; from first edit {number(t['fromFirstEditThinkingTokens'])}. Classified repair subset: {number(r['repairEffort']['observedReasoningTokens'])}; first classified failure feedback turn: {r['repairEffort'].get('firstFailureFeedbackTurn')}; feedback kind: {r['repairEffort'].get('failureFeedbackKind')}.", '',
                  f"Actions: {dict(sorted(counts.items()))}. Observed source transitions: {t['observedSourceTransitions']}; distinct source identities: {t['distinctSourceIdentities']}. Checked-query time: {journal_seconds:.6f}s; reused/fresh components: {r['reusedComponents']}/{r['freshComponents']}; reconstruction queries: {r['reconstructionQueries']} (excluded from these checker totals).", '',
                  f"Summed provider request time: {number(t['providerSeconds'])}s; peak tariff estimate: {t['peakDollarEstimate']:.6f} USD." if t['peakDollarEstimate'] is not None else 'Tariff estimate: unknown.', '',
                  '| Turn | Phase | Thinking | Cumulative thinking | Input / cached | Output incl. thinking | Peak USD | Request seconds | Observed actions and results |',
                  '| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |']
        for turn in t['rounds']:
            action_labels = []
            for a in turn['actions']:
                flags = [f'{k}={a[k]}' for k in ('edited', 'rejected', 'exitCode', 'allChecksPassed', 'verified', 'counts', 'assessedDomainClaims', 'failedDomainClaims') if k in a and (k != 'rejected' or a[k])]
                action_labels.append(a['name'] + (': '+', '.join(flags) if flags else ''))
            dollars = 'unknown' if turn['peakDollarEstimate'] is None else f"{turn['peakDollarEstimate']:.6f}"
            seconds = 'unknown' if turn['providerSeconds'] is None else f"{turn['providerSeconds']:.3f}"
            lines.append(f"| {turn['turn']} | {turn['phase']} | {number(turn['thinkingTokens'])} | {number(turn['cumulativeThinkingTokens'])} | {number(turn['inputTokens'])} / {number(turn['cachedInputTokens'])} | {number(turn['outputIncludingThinkingTokens'])} | {dollars} | {seconds} | {'; '.join(action_labels) or 'no tool action'} |")
        lines.append('')
    return lines
