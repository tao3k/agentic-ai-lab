# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Complete domain intervention accounting without reading private reasoning."""
import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path

from ascent import Engine
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price
from .repository_statistics import records, billing, repair_effort
from .repository_metrics import trajectory_metrics, integrated_metrics, metric_report


def candidate_repair(attempts):
    """Whole-turn work after a uniformly assessed failing candidate.

    An initial defect observation before any edit is diagnosis. An independently
    rejected submission always counts as a rejected candidate. Offline checks
    are labelled assessments, not feedback invented in the model history.
    """
    edited=False
    def repair_at(index,kind):
        effort=until_verified(attempts[index:])
        selected=attempts[index:index+effort['attempts']]
        return {'firstFailureTurn':attempts[index]['turn'],'failureKind':kind,
                **effort,'peakDollarEstimate':sum(price(a['usage']) for a in selected) if effort['modelUsageComplete'] else None}
    for index,attempt in enumerate(attempts):
        for action in attempt['actions']:
            result=action.get('result')
            if not isinstance(result,dict):continue
            if action['name']=='edit_source' and result.get('edited'):edited=True
            rejected=action['name'] in ('submit_patch','implicit_submit') and result.get('verified') is False
            bad_control=action['name']=='run_checks' and result.get('allChecksPassed') is False
            bad_domain=any(not flag for c in result.get('auditDomainChecks',[]) for _,flag in c['claims'])
            if rejected or (edited and (bad_control or bad_domain)):
                return repair_at(index,'independent-submission' if rejected else 'domain-assessment' if bad_domain else 'development-check')
        if any(g.get('verified') is False for g in attempt.get('candidateChecks',[])):
            return repair_at(index,'independent-candidate-check')
    return {'firstFailureTurn':None,'observedReasoningTokens':0,'modelCalls':0,'peakDollarEstimate':0}


def summarize(plan_dir, output, engine=None):
    plan=json.loads((plan_dir/'plan.json').read_text()); raw=records(output)
    if hashlib.sha256((plan_dir/'libascent.dylib').read_bytes()).hexdigest()!=plan['librarySha256']:
        raise ValueError('checker library differs from frozen qualification')
    engine=engine or Engine(plan_dir/'libascent.dylib');entries=[]
    for r in raw:
        case=next(c for c in plan['tasks'] if c['name']==r['task'])
        assessed=copy.deepcopy(r['attempts']);domain_observations=0
        for attempt in assessed:
            for action in attempt['actions']:
                result=action.get('result')
                if isinstance(result,dict) and result.get('domainObservations'):
                    checked=engine.request({'operation':'domain-check','kind':case['domainKind'],'observations':result['domainObservations']})
                    result['auditDomainChecks']=checked['checks'];domain_observations+=1
        journal=r.get('evidenceJournal',[]);domain=r.get('domainJournal',[])
        rejections=Counter(a['result']['error'][:180] for attempt in r['attempts'] for a in attempt['actions']
                           if isinstance(a.get('result'),dict) and a['result'].get('error'))
        entries.append({'task':r['task'],'repetition':r['repetition'],'arm':r['arm'],'status':r['status'],
                        'episodeReceipt':r['episodeReceipt'],'episodeSha256':r['episodeSha256'],
                        'effort':until_verified(r['attempts']),'repairEffort':repair_effort(r['attempts']),
                        'candidateRepairEffort':candidate_repair(assessed),'domainObservationCalls':domain_observations,
                        'toolRejectionReasons':dict(rejections),
                        'checkedEvidenceQueries':len(journal)+len(domain),
                        'reusedComponents':sum(len(j['reusedComponents']) for j in journal+domain),
                        'freshComponents':sum(len(j['freshComponents']) for j in journal+domain),
                        'checkedEvidenceSeconds':sum(j['seconds'] for j in journal+domain),'reconstructionQueries':0,
                        'trajectory':trajectory_metrics(assessed,primary_turns=plan['maxTurns'])})
    entries.sort(key=lambda r:(r['task'],r['repetition'],r['arm']))
    pairs=[]
    for row in entries:
        if row['arm']=='ordinary-tools':continue
        baseline=next((r for r in entries if (r['task'],r['repetition'],r['arm'])==(row['task'],row['repetition'],'ordinary-tools')),None)
        if baseline is None:continue
        pairs.append({'task':row['task'],'repetition':row['repetition'],'arm':row['arm'],
                      'thinkingReduction':paired_reduction(baseline['effort'],row['effort'],'observedReasoningTokens'),
                      'baselineThinking':baseline['effort']['observedReasoningTokens'],'candidateThinking':row['effort']['observedReasoningTokens'],
                      'baselineVerified':baseline['effort']['verified'],'candidateVerified':row['effort']['verified'],
                      'baselineCalls':baseline['effort']['modelCalls'],'candidateCalls':row['effort']['modelCalls']})
    terminal=output/'result.json'
    complete=terminal.exists() and json.loads(terminal.read_text()).get('complete',False)
    runtime_path=plan_dir.parent/'runtime-versions.json'
    audit_path=output/'candidate-audit.json'
    audit=json.loads(audit_path.read_text()) if audit_path.exists() else None
    if audit:
        for r in audit['trajectories']:
            original=next(x for x in entries if (x['task'],x['arm'],x['repetition'])==(r['task'],r['arm'],r['repetition']))
            if original['episodeSha256']!=r['episodeSha256']:raise ValueError('candidate audit episode identity differs')
    return {'schema':'ascent.domain-repository-report.v1','complete':complete,'planSha256':hashlib.sha256((plan_dir/'plan.json').read_bytes()).hexdigest(),
            'engineLibrarySha256':plan['librarySha256'],'frozenProducerHashes':plan['producerHashes'],
            'questions':[{k:c[k] for k in ('name','question','editable','domainKind','qualification','provenance','snapshotIdentity','graderSha256')} for c in plan['tasks']],
            'observedRuntime':json.loads(runtime_path.read_text()) if runtime_path.exists() else None,
            'candidateDiscoveryAudit':audit,
            'episodes':entries,'pairs':pairs,'integratedMetrics':integrated_metrics(entries,pairs),'billing':billing(output),
            'analysisProducerHashes':{name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() for name in ('domain_repository_report.py','repository_statistics.py','repository_metrics.py','inference_effort.py','inference_reuse_study.py')}},plan


def report(data,plan):
    lines=['<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->','<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->','',
           '# Executed Domain Evidence: Real Repository Comparison','',
           '## Objective, mechanism and protocol','',
           'Measure provider-reported cumulative thinking through first independent selected-grader acceptance, charging all prior diagnosis, rejected edits and failed candidates. Answer length is not a savings denominator.', '',
           f"Status: **{'completed' if data['complete'] else 'running'}**. Frozen plan: {len(plan['tasks'])} root causes × {len(plan['arms'])} conditions × {plan['repetitions']} repetitions = {len(plan['tasks'])*len(plan['arms'])*plan['repetitions']} trajectories, each with a uniform {plan['maxTurns']}-turn primary ceiling. No reset, selective retry or adaptive continuation is included.",'',
           'Ordinary tools expose actual execution observations. Fresh Scheme additionally checks the current domain observation. Retained Scheme adds current-snapshot checked memory and checker-qualified contracts to later model turns. Source edits invalidate execution claims; mathematical contracts remain qualified by the same frozen checker. A checker-version change clears both. Unlike the previous cache-only comparison, retained feedback is explicitly different and its input-token cost is charged. This compares domain support plus retrieval, not persistence alone. Every condition preserves complete opaque provider history.', '',
           'The model receives the complete problem and may reason naturally. Tool choice is automatic; no mandatory subproblem protocol or strict response format is imposed. Output ceiling is 131,072 tokens. Model alias: deepseek-flash, high reasoning effort; an alias is not an immutable model revision attestation.', '',
           '## Sources, complexity and independent acceptance','',
           'The graph task is [NetworkX PR 8906](https://github.com/networkx/networkx/pull/8906), disclosed September 13, 2026. It is outside the previous September-20 window; this new run explicitly declares a September-1 window before paid execution. It was not a task in the previous paid comparison. The symbolic task is [SymPy PR 30702](https://github.com/sympy/sympy/pull/30702), disclosed October 8, 2026. These concern row-normalization and post-condition solution coverage, distinct from the previous group-traversal and root-precision defects. Recent rs_pow valuation fixes are not counted as independent holdouts because they share the prior precision root-cause family. Training/retrieval exposure remains unknown.', '',
           'Both tasks have interacting algorithmic obligations but small edit scopes and named functions. Their difficulty is not calibrated; long trajectories or tool rejections do not establish difficulty. The graph grader combines upstream controls with a separate implementation of the structural-hole summation on new directed/undirected weighted graphs, labels, scaling and isolates. The symbolic grader combines upstream branch-preservation controls with independently checked ODE residuals, initial conditions and three parameter values. These augmentations remain finite and do not prove all repository behavior.', '']
    lines += ['Both Scheme conditions also expose checked local syntactic-reference support during source reads. Thus comparison with ordinary tools measures the combined Scheme assistance package. Retained versus fresh additionally changes component persistence and retrieved domain context; this is not a clean domain-only or persistence-only causal estimate.', '', '## Measured outcome', '']
    if plan.get('verifyCandidatesOnEdit'):
        lines += ['**Correction validation:** these are repeated roots from the [completed primary study](domain-repository-experiment-report.md), not new holdouts. There is one ordinary and one retained trajectory per root, and no fresh condition in this follow-up. Both conditions independently grade each admitted edit. Failed automatic grades remain host-side, without additional provider feedback; successful grades bind source bytes, grader identity and selected test scope, seal the candidate and stop further requests. This tests the acceptance guard addressing a primary trajectory that found a correct candidate and later overwrote it. The small follow-up is mechanism qualification, not a stable population savings estimate.', '']
    if data.get('observedRuntime'):
        runtime=data['observedRuntime']
        lines += [f"Observed local runtime: Python {runtime['python']}; dependency distributions {runtime['dependencies']}. Versions were recorded during execution and are not an immutable environment attestation. Frozen engine library SHA-256: `{data['engineLibrarySha256']}`. Producer hashes and source identities are in the JSON companion.",'']
    for s in data['integratedMetrics']:
        rows=[r for r in data['episodes'] if r['arm']==s['arm']]
        repair=(sum(r['candidateRepairEffort']['observedReasoningTokens'] for r in rows)
                if all(r['candidateRepairEffort'].get('reasoningUsageComplete',True) for r in rows) else None)
        show=lambda n:'unknown' if n is None else f'{n:,}'
        reduction=s['pairedWeightedReduction']
        paired='not estimable' if reduction is None else f'{100*reduction:.2f}%'
        lines.append(f"- {s['arm']}: {s['accepted']}/{s['trajectories']} independently accepted; {show(s['thinkingIncludingCensored'])} thinking tokens including censored trajectories; {show(repair)} candidate-repair thinking tokens (already included); jointly accepted paired reduction {paired} across {s['jointlyAcceptedPairs']} pairs.")
    lines += ['', 'A positive paired reduction applies only to jointly accepted runs. A failed or censored run cannot establish savings by consuming fewer tokens. Two repetitions do not establish statistical significance or stable savings on other tasks. The 40–50% target is a hypothesis; the measured paired values and acceptance rates above determine whether this pilot supports it.', '']
    for c in plan['tasks']:
        q=c['qualification']
        lines += [f"### {c['name']}",'',c['question'],'',
                  f"Parent `{c['provenance']['parentCommit']}`; fixed `{c['provenance']['fixedCommit']}`. Failure-to-pass identities: {len(q['failToPass'])}; passing controls: {len(q['passToPass'])}; selected identities: {len(c['expectedTestNames'])}. Snapshot `{c['snapshotIdentity']}`; grader `{c['graderSha256']}`.",'']
    lines += ['## Repair accounting and actual intervention exposure','',
              'Feedback repair uses the prior definition: work from the first failed development check or rejected independent submission, including that whole provider turn. Candidate repair additionally applies the SAME frozen Scheme checker offline to observed values in all conditions, including ordinary tools. It starts at the first assessed failing execution after an admitted edit, or any independently rejected submission. Original-defect observations before editing are diagnosis, not failed repairs. Offline assessment is not invented model feedback; episode files and their hashes remain unchanged. Missing observation coverage is not interpreted as a pass. Whole-turn usage cannot be split among actions; repair is a subset of total thinking and must not be added again.', '',
              '| Task | Rep | Condition | Status | Calls | Total thinking | Candidate repair thinking / start turn | Domain observation calls |',
              '| --- | ---: | --- | --- | ---: | ---: | ---: | ---: |']
    for r in data['episodes']:
        repair=r['candidateRepairEffort']
        lines.append(f"| {r['task']} | {r['repetition']+1} | {r['arm']} | {r['status']} | {r['effort']['modelCalls']} | {r['effort']['observedReasoningTokens']:,} | {repair['observedReasoningTokens']:,} / {repair['firstFailureTurn']} | {r['domainObservationCalls']} |")
    audit=data.get('candidateDiscoveryAudit')
    if audit:
        lines += ['', '## First independently valid candidate versus submitted acceptance', '',
                  'This is an explicitly post-run secondary measurement. Public admitted edits are replayed from frozen parent source; every replay must match its recorded source identity. The same independent selected grader is applied to successive candidates until first pass. No private reasoning is read, no new provider calls are made and no offline verdict is supplied to the model. Original episode receipts, censoring and submission endpoints remain unchanged. A source candidate passing before submission is an observed discovery, not evidence that the model or deployed protocol knew to stop then.', '',
                  'Whole provider-turn thinking through the first valid candidate is charged. Continued thinking after that candidate remains fully billed; it cannot be advertised as savings already achieved. A final candidate can differ from an earlier correct candidate. Bounded execution timeouts count as failed resource qualification, not proof of mathematical incorrectness.', '']
        rows=sorted(audit['trajectories'],key=lambda r:(r['task'],r['repetition'],r['arm']))
        lines += ['| Condition | Valid candidate discovered | Final candidate accepted | Thinking through first valid candidate | Rejected-candidate repair thinking |',
                  '| --- | ---: | ---: | ---: | ---: |']
        for arm in sorted({r['arm'] for r in rows}):
            selected=[r for r in rows if r['arm']==arm]
            lines.append(f"| {arm} | {sum(r['firstValidCandidateTurn'] is not None for r in selected)}/{len(selected)} | {sum(r['finalCandidateVerified'] for r in selected)}/{len(selected)} | {sum(r['effort']['observedReasoningTokens'] for r in selected):,} | {sum(r['repairEffort']['observedReasoningTokens'] for r in selected):,} |")
        before=sum(r['effort']['observedReasoningTokens'] for r in rows)
        charged=sum(r['effort']['observedReasoningTokens'] for r in data['episodes'])
        lines += ['',f"First-candidate thinking totals {before:,}; actual charged trajectory thinking totals {charged:,}. The difference is {charged-before:,} ({100*(charged-before)/charged:.2f}%) after first independently valid candidates. This is an observed stopping opportunity within the selected test scope, NOT already achieved deployment savings. Later work may concern robustness outside that finite scope. It must not be added to the Scheme-versus-baseline paired reduction.", '',
                  '| Task | Rep | Condition | First valid candidate turn | Thinking through candidate | Rejected-candidate repair thinking | Subsequent billed thinking | Final candidate accepted |',
                  '| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |']
        for r in rows:
            primary=next(x for x in data['episodes'] if (x['task'],x['arm'],x['repetition'])==(r['task'],r['arm'],r['repetition']))
            later=primary['effort']['observedReasoningTokens']-r['effort']['observedReasoningTokens'] if r['firstValidCandidateTurn'] is not None else None
            lines.append(f"| {r['task']} | {r['repetition']+1} | {r['arm']} | {r['firstValidCandidateTurn']} | {r['effort']['observedReasoningTokens']:,} | {r['repairEffort']['observedReasoningTokens']:,} | {later if later is not None else 'not estimable'} | {r['finalCandidateVerified']} |")
        lines += ['', '### Candidate-discovery matched reductions', '', '| Task | Rep | Candidate | Thinking baseline / candidate | Reduction |', '| --- | ---: | --- | ---: | ---: |']
        for r in rows:
            if r['arm']=='ordinary-tools':continue
            baseline=next(x for x in rows if (x['task'],x['repetition'],x['arm'])==(r['task'],r['repetition'],'ordinary-tools'))
            reduction=paired_reduction(baseline['effort'],r['effort'],'observedReasoningTokens')
            shown='not estimable' if reduction is None else f'{100*reduction:.2f}%'
            lines.append(f"| {r['task']} | {r['repetition']+1} | {r['arm']} | {baseline['effort']['observedReasoningTokens']:,} / {r['effort']['observedReasoningTokens']:,} | {shown} |")
        lines.append('')
        for arm in sorted({r['arm'] for r in rows}-{'ordinary-tools'}):
            eligible=[]
            for r in rows:
                if r['arm']!=arm:continue
                baseline=next(x for x in rows if (x['task'],x['repetition'],x['arm'])==(r['task'],r['repetition'],'ordinary-tools'))
                if baseline['effort']['verified'] and r['effort']['verified']:eligible.append((baseline,r))
            denominator=sum(b['effort']['observedReasoningTokens'] for b,r in eligible)
            candidate=sum(r['effort']['observedReasoningTokens'] for b,r in eligible)
            if denominator:lines.append(f"- First-valid-candidate weighted reduction for {arm}: {100*(1-candidate/denominator):.2f}% across {len(eligible)} jointly valid pairs. This is the secondary discovery endpoint, not primary submitted acceptance.")
    b=data['billing']
    lines += ['', '### Tool validation and transport are separate', '',
              'Tool validation rejections remain charged in each trajectory. They are not provider API request rejections. No tool error is reclassified as a successful domain check.', '',
              '| Task | Rep | Condition | Tool rejection reason | Count |', '| --- | ---: | --- | --- | ---: |']
    for r in data['episodes']:
        for reason,count in r['toolRejectionReasons'].items():
            lines.append(f"| {r['task']} | {r['repetition']+1} | {r['arm']} | {reason.replace('|','/')} | {count} |")
    lines += ['', '## Provider expense','',
              f"Started requests: {b['startedRequests']}; responses with usage: {b.get('observedCalls',0)}; observed thinking: {b.get('observedReasoningTokens',0):,}. Unknown-usage requests: {len(b['unknownUsageRequests'])}. Peak tariff estimate: ${b.get('peakDollarEstimate',0):.6f}; off-peak estimate: ${b['offPeakDollarEstimate']:.6f}. Unknown charges are not zero; account debit is unverified. Cached provider input discounts and Scheme evidence reuse are different mechanisms. Pricing basis: [official DeepSeek pricing](https://api-docs.deepseek.com/quick_start/pricing/).", '',
              '## Formal and execution evidence boundaries','',
              'Scheme implements exact traversal, graph-update and rational precision checks. Lean proves update conservation/nonnegativity, rational precision restoration, boundary exclusion, filtered-membership and snapshot/checker rejection contracts. Actual Scheme outputs correspond with Lean and Quint on 2,400 precision cases and 500 graph-update cases. Quint also exercises retention/invalidation over 10,000 traces of 30 transitions. These are bounded correspondence and contract proofs, not proofs of Python collection, the JSON/CFFI parser, all graph algorithms or the symbolic solver.', '',
              'The prior root-precision and traversal defects are development qualification tasks, not reused primary holdouts. Row normalization is checked against exact receipted pre/post values with a declared absolute tolerance. Symbolic specialization carries a delegated SymPy simplification witness; Scheme enforces its scoped zero-witness and duplication contract. Complete question/action/token ledgers below describe measured executions; private model reasoning is not reproduced.', '']
    followup=data.get('candidateGuardValidation')
    if followup:
        lines += ['', '## Verified candidate guard: real correction validation', '',
                  'The primary audit found a retained ODE trajectory with a correct candidate at turn 11 and an incorrect final candidate after further edits. The implementation now independently checks every admitted candidate, seals matching source bytes with grader identity and selected test scope on acceptance, and ends the trajectory. Source edits after sealing are rejected. Rechecking copied bytes prevents a changed source from being stored under an older qualification. Failed automatic grades are stored host-side and do not add hidden-test feedback to provider history.', '',
                  'This follow-up repeats the same two roots with ordinary and retained conditions, one repetition each, under the same 40-turn ceiling. It is correction qualification, not a new independent holdout set. Both conditions receive the guard, so the paired comparison continues to measure Scheme assistance above the common acceptance policy. The guard changes the stopping policy; primary and follow-up savings are not pooled.', '',
                  '| Task | Condition | Independently accepted | Calls | Thinking before acceptance | Failed-candidate repair thinking |',
                  '| --- | --- | --- | ---: | ---: | ---: |']
        for r in followup['episodes']:
            lines.append(f"| {r['task']} | {r['arm']} | {r['effort']['verified']} | {r['effort']['modelCalls']} | {r['effort']['observedReasoningTokens']:,} | {r['candidateRepairEffort']['observedReasoningTokens']:,} |")
        selected=next(s for s in followup['integratedMetrics'] if s['arm']=='scheme-retained')
        lines += ['', f"All {sum(r['effort']['verified'] for r in followup['episodes'])}/{len(followup['episodes'])} guard trajectories were independently accepted and sealed. Retained paired thinking reduction: {100*selected['pairedWeightedReduction']:.2f}% across {selected['jointlyAcceptedPairs']} pairs. This does not meet a stable 40–50% target. Per-root regressions remain in the complete ledger below.", '',
                  'Lean now also states stale-source, changed-copy and changed-grader rejection, and disallows edits to a sealed state. A separate Quint verified-candidate model checks the artifact source/grader binding over 10,000 traces of 30 transitions. These are conditional admission/state contracts, not a proof of Python filesystem operations or the independent grader.', '']
        bill=followup['billing']
        lines += [f"Combined actual expense for both phases: {b['observedCalls']+bill['observedCalls']} requests with usage, {b['observedReasoningTokens']+bill['observedReasoningTokens']:,} thinking tokens, peak tariff estimate ${b['peakDollarEstimate']+bill['peakDollarEstimate']:.6f}. All earlier failed, censored and post-discovery requests remain charged. Offline candidate grading made no provider calls. Account debit remains unverified.", '']
    lines += metric_report(data)
    if followup:
        lines += ['', '## Complete correction-validation ledger', '']
        lines += ['#'+line if line.startswith('#') else line for line in metric_report(followup)]
    return '\n'.join(lines)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('plan','output','destination'):parser.add_argument(name,type=Path)
    parser.add_argument('--guard-plan',type=Path);parser.add_argument('--guard-output',type=Path)
    args=parser.parse_args();engine=Engine(args.plan/'libascent.dylib');data,plan=summarize(args.plan,args.output,engine)
    if args.guard_plan or args.guard_output:
        if not (args.guard_plan and args.guard_output):parser.error('both guard paths required')
        if hashlib.sha256((args.guard_plan/'libascent.dylib').read_bytes()).hexdigest()!=plan['librarySha256']:
            parser.error('different checker libraries require separate analysis processes')
        followup,_=summarize(args.guard_plan,args.guard_output,engine)
        data['candidateGuardValidation']=followup
    args.destination.write_text(report(data,plan)+'\n');args.destination.with_suffix('.json').write_text(json.dumps(data,indent=2)+'\n')
    print('DOMAIN-REPORT',data['complete'],len(data['episodes']),data['billing'].get('observedCalls',0),flush=True)
