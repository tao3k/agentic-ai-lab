# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Audit completed frozen trajectories without changing their outcomes or costs."""
import argparse
import hashlib
import json
from pathlib import Path
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price

FAILURES={'action_failure','answer_not_verified','output_budget_exhausted','provider_failure'}


def summarize_episode(episode):
    attempts=episode['attempts'];effort=until_verified(attempts)
    failures=[i for i,a in enumerate(attempts) if a.get('outcome') in FAILURES or
              a.get('providerOutcome') not in (None,'completed_ungraded')]
    first=failures[0] if failures else None
    # The suffix is observed failure + repair work, not an assertion that every
    # token in it was avoidable. A censored suffix is still charged.
    repair=until_verified(attempts[first:]) if first is not None else until_verified([])
    aliases=set();extensions=0;exposures=0;completed_hits=0;query_calls=0;answers=[];labels=[]
    for attempt in attempts:
        if aliases:exposures+=attempt['providerCalls']
        records=attempt.get('toolActions') or [attempt]
        call_labels=[]
        for record in records:
            action=record.get('action',{});kind=action.get('action')
            call_labels.append(kind if isinstance(kind,str) else 'invalid action shape')
            if kind=='answer':answers.append(record)
            if kind=='query':
                query_calls+=1
                referenced={a['relation'] for r in action['contract']['rules'] for a in r['body']}
                extensions+=bool(referenced & aliases)
                feedback=record.get('feedback',{})
                completed_hits+=bool(feedback.get('retainedCompleted'))
                aliases.update(x['relation'] for x in feedback.get('publishedEvidence',[]))
        labels.append('+'.join(call_labels))
    return {'firstAnswerCorrect':bool(answers and answers[0]['correct']),'answerAttempts':len(answers),
            'case':episode['case'],'repetition':episode['repetition'],'arm':episode['arm'],
            'effort':effort,'failureAttempts':len(failures),'firstFailureTurn':first+1 if first is not None else None,
            'failureAndRepairEffort':repair,'postFailureModelCalls':max(0,repair['modelCalls']-1) if first is not None else 0,
            'peakEstimateUsd':sum(price(a['usage']) for a in attempts if a.get('usage')),
            'failureAndRepairPeakEstimateUsd':sum(price(a['usage']) for a in attempts[first:] if a.get('usage')) if first is not None else 0,
            'queryActions':query_calls,'evidencePublished':bool(aliases),'laterCallsExposedToEvidence':exposures,
            'aliasExtensionQueries':extensions,'completedPathHits':completed_hits,
            'actions':labels,
            'failureDetails':[{'turn':i+1,'outcome':a.get('outcome'),
                               'feedback':a.get('feedback') or [t.get('feedback') for t in a.get('toolActions',[])],'thinkingTokens':(a.get('usage') or {}).get('output_tokens_details',{}).get('reasoning_tokens')}
                              for i,a in enumerate(attempts) if i in failures]}


def summarize(plan,receipt):
    episodes=[summarize_episode(e) for e in receipt['episodes']]
    expected=len(plan['cases'])*len(plan['arms'])*plan['repetitions']
    if len(episodes)!=expected or 'pairs' not in receipt:raise ValueError('experiment incomplete; do not publish a completed report')
    keys={(e['case'],e['repetition'],e['arm']) for e in episodes}
    if len(keys)!=expected:raise ValueError('duplicate trajectories')
    groups={}
    for arm in plan['arms']:
        values=[e for e in episodes if e['arm']==arm]
        groups[arm]={'trajectories':len(values),'verified':sum(e['effort']['verified'] for e in values),
                     'accuracy':sum(e['effort']['verified'] for e in values)/len(values),
                     'firstAnswerCorrect':sum(e['firstAnswerCorrect'] for e in values),
                     'answerAttempts':sum(e['answerAttempts'] for e in values),
                     'consumedReasoningTokens':sum(e['effort']['observedReasoningTokens'] for e in values),
                     'modelCalls':sum(e['effort']['modelCalls'] for e in values),
                     'consumedInputTokens':sum(e['effort']['inputTokens'] for e in values),
                     'consumedOutputTokens':sum(e['effort']['outputIncludingReasoningTokens'] for e in values),
                     'failureAttempts':sum(e['failureAttempts'] for e in values),
                     'failureAndRepairReasoningTokens':sum(e['failureAndRepairEffort']['observedReasoningTokens'] for e in values),
                     'failureAndRepairModelCalls':sum(e['failureAndRepairEffort']['modelCalls'] for e in values),
                     'failureAndRepairPeakEstimateUsd':sum(e['failureAndRepairPeakEstimateUsd'] for e in values),
                     'peakEstimateUsd':sum(e['peakEstimateUsd'] for e in values),
                     'evidenceAdoption':sum(e['evidencePublished'] for e in values),
                     'aliasExtensionQueries':sum(e['aliasExtensionQueries'] for e in values),
                     'schemeSeconds':sum(e['effort']['schemeSeconds'] for e in values),
                     'providerSeconds':sum(a.get('providerSeconds',0) for e in receipt['episodes'] if e['arm']==arm for a in e['attempts']),
                     'reasoningUsageComplete':all(e['effort']['reasoningUsageComplete'] for e in values),
                     'modelUsageComplete':all(e['effort']['modelUsageComplete'] for e in values)}
    pairs=[]
    for case in plan['cases']:
        for rep in range(plan['repetitions']):
            b=next(e for e in episodes if e['case']==case['name'] and e['repetition']==rep and e['arm']==plan['arms'][0])
            a=next(e for e in episodes if e['case']==case['name'] and e['repetition']==rep and e['arm']==plan['arms'][1])
            pairs.append({'case':case['name'],'repetition':rep,
                          'bothVerified':b['effort']['verified'] and a['effort']['verified'],
                          'thinkingReduction':paired_reduction(b['effort'],a['effort'],'observedReasoningTokens'),
                          'modelTurnReduction':paired_reduction(b['effort'],a['effort'],'modelCalls')})
    complete=[p for p in pairs if p['bothVerified']]
    measurable=[p for p in complete if p['thinkingReduction'] is not None]
    selected={(p['case'],p['repetition']) for p in measurable}
    matched={arm:sum(e['effort']['observedReasoningTokens'] for e in episodes if e['arm']==arm and (e['case'],e['repetition']) in selected) for arm in plan['arms']}
    denominator=matched[plan['arms'][0]]
    return {'schema':'ascent.compound-thinking-audit.v1','groups':groups,'episodes':episodes,'pairs':pairs,
            'jointlyVerifiedPairs':len(complete),'measurableThinkingPairs':len(measurable),'totalPairs':len(pairs),'jointlyVerifiedThinkingTokens':matched,
            'jointlyVerifiedThinkingReduction':1-matched[plan['arms'][1]]/denominator if denominator else None,
            'scope':'Observed cumulative thinking effort; does not identify exact redundant internal token spans. Jointly verified subset must be read alongside all-arm accuracy and censored costs.'}


def render_report(plan,audit,receipt,*,prefix='compound',include_questions=True):
    def pct(value):return 'Undefined (unverified pair)' if value is None else f'{value*100:.2f}%'
    lines=['# Complex reasoning with Scheme evidence: real multi-round comparison',
           '', '## Research objective', '',
           'Measure whether source-bound Scheme evidence reduces cumulative model thinking to the first independently verified correct answer on four compound questions. The model reasons about each complete question; Scheme checks externally expressed derivations and retains evidence for later reasoning. Subproblem-first planning is not required.',
           '', '## Experiment plan and boundaries', '',
           f"Four frozen synthetic questions, two trials per condition, {len(audit['episodes'])} trajectories, at most {plan['maxTurns']} turns per trajectory. Both conditions can scan the same raw facts. Each source contains 96 Actors, 32 Films, 8 Directors, 4 Countries and 391 facts. Entity IDs are opaque. Trials start fresh; these are repeated cold trials, not free warm-cache trials.",
           '', 'Control reasons over raw facts. Assistance additionally has executable claim checking, evidence publication and source-bound alias reuse. No mandatory first-round query or evidence-use gate for a correct answer. Private gold programs, values and counts are excluded from requests. Verification returns only verified/not_verified. Incorrect actions and answers consume turns; no automatic paid retry or post-hoc primary-score replacement.',
           '', f"Requested model: deepseek-flash; reasoning effort: high; output ceiling: {plan['maxOutputTokens']:,} per call. Frozen plan SHA-256: `{audit['planSha256']}`. Runtime artifact SHA-256: `{plan['librarySha256']}`.",
           '', '## Complete questions', '']
    if include_questions:
        for case in plan['cases']:
            lines.extend(['### '+case['family'],'',case['question'],''])
    else:
        lines.extend(['The complete questions above are unchanged in this phase.',''])
    lines.extend(['## Accuracy and total consumed work', '',
                  '| Condition | Verified / trajectories | Accuracy | First submitted answer correct / assigned | Model calls | Thinking tokens | Input tokens | Output incl. thinking | Scheme/local action seconds |',
                  '|---|---:|---:|---:|---:|---:|---:|---:|---:|'])
    for arm,g in audit['groups'].items():
        lines.append(f"| {arm} | {g['verified']}/{g['trajectories']} | {g['accuracy']*100:.1f}% | {g['firstAnswerCorrect']}/{g['trajectories']} | {g['modelCalls']} | {g['consumedReasoningTokens']:,} | {g['consumedInputTokens']:,} | {g['consumedOutputTokens']:,} | {g['schemeSeconds']:.4f} |")
    lines.extend(['', 'All consumed work includes unsuccessful trajectories. Usage completeness is recorded in the audit. Thinking tokens are a subset of output tokens, not an extra billable amount. Local action time includes scans, oracle grading and failed action handling as well as Scheme queries; it is not pure engine compute time. Runtime initialization and pre-turn store admission are outside that timer.',
                  '', '## First-correct trajectories', '',
                  '| Question | Trial | Condition | Verified | Calls through first correct / censoring | Thinking tokens | Observable actions |',
                  '|---|---:|---|---|---:|---:|---|'])
    for e in audit['episodes']:
        lines.append(f"| {e['case']} | {e['repetition']+1} | {e['arm']} | {'Yes' if e['effort']['verified'] else 'No: censored'} | {e['effort']['modelCalls']} | {e['effort']['observedReasoningTokens']:,} | {' → '.join(e['actions'])} |")
    lines.extend(['', '## Results by question family', '',
                  '| Family | Control verified | Scheme verified | Control thinking | Scheme thinking | Reduction on jointly verified trials |',
                  '|---|---:|---:|---:|---:|---:|'])
    for case in plan['cases']:
        values=[e for e in audit['episodes'] if e['case']==case['name']]
        grouped=[[e for e in values if e['arm']==arm] for arm in plan['arms']]
        joint={p['repetition'] for p in audit['pairs'] if p['case']==case['name'] and p['bothVerified'] and p['thinkingReduction'] is not None}
        thinking=[sum(e['effort']['observedReasoningTokens'] for e in g) for g in grouped]
        matched=[sum(e['effort']['observedReasoningTokens'] for e in g if e['repetition'] in joint) for g in grouped]
        reduction=1-matched[1]/matched[0] if matched[0] else None
        counts=[sum(e['effort']['verified'] for e in g) for g in grouped]
        lines.append(f"| {case['family']} | {counts[0]}/{len(grouped[0])} | {counts[1]}/{len(grouped[1])} | {thinking[0]:,} | {thinking[1]:,} | {pct(reduction)} ({len(joint)} pairs) |")
    lines.extend(['', '## Matched thinking reductions', '',
                  '| Question | Trial | Both verified | Thinking reduction | Turn reduction |',
                  '|---|---:|---|---:|---:|'])
    for pair in audit['pairs']:
        lines.append(f"| {pair['case']} | {pair['repetition']+1} | {'Yes' if pair['bothVerified'] else 'No'} | {pct(pair['thinkingReduction'])} | {pct(pair['modelTurnReduction'])} |")
    lines.extend(['', f"Jointly verified pairs: **{audit['jointlyVerifiedPairs']}/{audit['totalPairs']}**. Measurable thinking pairs: {audit['measurableThinkingPairs']}. Weighted cumulative thinking reduction on that measurable subset: **{pct(audit['jointlyVerifiedThinkingReduction'])}**. Positive means less thinking; negative means more. Read this subset together with full-condition accuracy and censored consumed costs; it does not erase failed trajectories.",
                  '', '## Failure and repair costs', '',
                  '| Condition | Failed attempts | Failure + repair calls | Failure + repair thinking | Peak-price estimate USD |',
                  '|---|---:|---:|---:|---:|'])
    for arm,g in audit['groups'].items():
        lines.append(f"| {arm} | {g['failureAttempts']} | {g['failureAndRepairModelCalls']} | {g['failureAndRepairReasoningTokens']:,} | {g['failureAndRepairPeakEstimateUsd']:.6f} |")
    lines.extend(['', 'Failure + repair includes the first failed attempt and every later call until verification or censoring. It is a measured suffix cost, not proof that every token was avoidable. Ordinary successful evidence-building before a failure remains charged in the trajectory total. Adaptive follow-up costs, when present, are reported separately and never overwrite this frozen phase.',
                  '', '### Observed failure feedback', ''])
    for e in audit['episodes']:
        for failure in e['failureDetails']:
            feedback=json.dumps(failure['feedback'],ensure_ascii=True).replace('|','\\|')
            lines.append(f"- {e['case']}, trial {e['repetition']+1}, {e['arm']}, turn {failure['turn']}: {failure['outcome']}; thinking {failure['thinkingTokens']}; feedback `{feedback}`.")
    lines.extend(['', '## Evidence mechanism audit', ''])
    for arm,g in audit['groups'].items():
        lines.append(f"- {arm}: {g['evidenceAdoption']}/{g['trajectories']} trajectories published Scheme evidence; {g['aliasExtensionQueries']} later queries explicitly extended a published alias.")
    exposed=sum(e['laterCallsExposedToEvidence'] for e in audit['episodes'])
    hits=sum(e['completedPathHits'] for e in audit['episodes'])
    lines.extend(['',f"Later model calls exposed to published evidence: {exposed}. Completed retained-path hits: {hits}. Exposure is not proof that the model causally used each item. Adoption is self-selected; a treatment-only subset is descriptive, not a randomized causal estimate. Without explicit alias extension or a separate execution-only ablation, lower thinking cannot be attributed specifically to cross-round reuse rather than query execution assistance. The experiment does not identify exact redundant internal token spans.",
                  '', '## Resource accounting', '',
                  f"Total provider calls: **{receipt['providerCalls']}**. Conservative peak-price estimate: **USD {receipt['peakEstimateUsd']:.6f}**. Under the published weekend off-peak rates, the same usage prices at approximately **USD {receipt['peakEstimateUsd']/2:.6f}**; no invoice or account balance was retrieved. Prices: USD 0.30/M uncached input, 0.006/M cached input and 1.20/M output at peak, half off-peak. [Official pricing](https://api-docs.deepseek.com/quick_start/pricing/). Token usage, rather than visible answer byte count, is the basis. Scheme semantic reuse and provider prefix caching are separate mechanisms.",
                  '', '## Interpretation and limitations', '',
                  'These are four synthetic compound questions with two trials per condition, not a population accuracy estimate or an independently annotated real-world benchmark. Development choices are known; freezing prevents outcome-adaptive rewriting of these primary trials but does not create an external held-out benchmark. An execution-capable agent baseline would be needed to assess how much benefit is specific to ASCENT. A stable 40–50% claim needs preserved quality, repeated independent workloads and an ablation isolating retained evidence. Source withdrawal and semantic mutation controls passed offline; those controls are not additional paid model tasks.',
                  '', 'The actual frozen CFFI engine executed the evidence. Existing Lean/Quint correspondence qualifies bounded operator and reuse conditions; it does not prove natural-language intent, hidden thinking, arbitrary compilation or empirical token savings. Fresh-source Ubuntu CI is a distinct gate.',
                  '', '## Evidence files', '',
                  f'- [Frozen plan]({prefix}-thinking-plan.json)',
                  '- [Offline Scheme/oracle qualification](compound-thinking-qualification.json)',
                  f'- [Real-model receipt]({prefix}-thinking-result.json)',
                  f'- [Audited cumulative costs and pairs]({prefix}-thinking-audit.json)',
                  '', f"Requests and responses are retained under `.cache/ascent/movie-study/{'compound-thinking-tools-validated-real-20261010' if prefix=='tool' else 'compound-thinking-real-20261010'}/`; the tracked artifact manifest includes their identities. Frozen outcomes and costs are unchanged.", ''])
    return '\n'.join(lines)


def main():
    p=argparse.ArgumentParser();p.add_argument('plan',type=Path);p.add_argument('result',type=Path);p.add_argument('output',type=Path)
    a=p.parse_args();plan=json.loads(a.plan.read_text());receipt=json.loads(a.result.read_text())
    if hashlib.sha256(a.plan.read_bytes()).hexdigest()!=receipt['planSha256']:raise ValueError('plan identity mismatch')
    result=summarize(plan,receipt)
    result['planSha256']=receipt['planSha256'];result['rawResultSha256']=hashlib.sha256(a.result.read_bytes()).hexdigest()
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    a.output.with_suffix('.md').write_text(render_report(plan,result,receipt))
    print(json.dumps({'groups':result['groups'],'jointlyVerifiedPairs':result['jointlyVerifiedPairs'],
                      'thinkingReduction':result['jointlyVerifiedThinkingReduction']},indent=2))


if __name__=='__main__':main()
