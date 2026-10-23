# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Exact local ledger audit and English report for the path interface study."""
import hashlib
import copy
import json
import shutil
from pathlib import Path
from .interactive_study import balanced_oracle, tagged_oracle, obligation_acceptance
from agentic_ai_lab_runtime.reasoning import expand_feedback


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def count_thinking(call):return (call.get('usage') or {}).get('output_tokens_details',{}).get('reasoning_tokens')

def decode_historical(packet):
    if packet.get('encoding')!='ascent.branch-columns.v1':return expand_feedback(packet)
    packet=copy.deepcopy(packet);packet.pop('encoding');groups=packet.pop('groups');order=packet.pop('branchOrder');rows=[]
    for group in groups:
        for values,present in zip(group['rows'],group['present']):
            rows.append({**group['common'],**{k:v for k,v,p in zip(group['fields'],values,present) if p}})
    by_id={b['id']:b for b in rows};packet['branches']=[by_id[i] for i in order]
    return packet


def main():
    root=Path.cwd();cache=root/'.cache/ascent/path-consumption';out=root/'.cache/ascent/research-reports/path-consumption-study'
    out.mkdir(parents=True,exist_ok=True);records={};plans={};results=[];audit={};partial=[];disagreements=[];stage_costs=[]
    for folder in sorted(p for p in cache.iterdir() if p.is_dir() and (p/'records.json').exists()):
        data=json.loads((folder/'records.json').read_text());plan=json.loads((folder/'plan.json').read_text());records[folder.name]=data;plans[folder.name]=plan
        accepted,first=obligation_acceptance(data['verdicts']);calls=data['calls'];checks=data['checks']
        totals=sum(count_thinking(c) or 0 for c in calls);known=all(isinstance(count_thinking(c),int) for c in calls)
        repairing=set();failed=False
        for c in calls:
            if failed:repairing.add(c['id'])
            v=next((v for v in data['verdicts'] if v['providerCall']==c['id']),None)
            if v:failed=not v['correct']
        size_raw=sum(len(json.dumps(x['feedback'],separators=(',',':'))) for x in checks)
        size_exposed=sum(len(json.dumps(x.get('exposedFeedback',x['feedback']),separators=(',',':'))) for x in checks)
        row={'run':folder.name,'case':plan['case']['case'],'arm':plan['arm'],'finished':(folder/'result.json').exists(),
             'wholeTaskCorrect':all(accepted),'acceptedObligations':sum(accepted),'calls':len(calls),
             'thinkingObserved':totals,'thinkingComplete':known,'firstWholeCorrectThinking':totals if all(accepted) and known else None,
             'repairCalls':len(repairing),'repairThinking':sum(count_thinking(c) or 0 for c in calls if c['id'] in repairing),
             'failedFinalAnswers':sum(not v['correct'] for v in data['verdicts']),
             'inputTokens':sum((c.get('usage') or {}).get('input_tokens',0) for c in calls),
             'cachedInputTokens':sum((c.get('usage') or {}).get('input_tokens_details',{}).get('cached_tokens',0) for c in calls),
             'outputTokens':sum((c.get('usage') or {}).get('output_tokens',0) for c in calls),
             'providerSeconds':sum(c['seconds'] for c in calls),'nativeToolSeconds':sum(x['feedback'].get('seconds',0) for x in checks),
             'toolCalls':len(checks),'hostRevalidationCalls':sum(bool(x.get('revalidation')) for x in checks),
             'reuseToolCalls':sum(x.get('toolName')=='reuse_paths' for x in checks),'extendToolCalls':sum(x.get('toolName')=='extend_paths' for x in checks),
             'branchChecks':sum(len(x['feedback'].get('branches',[])) for x in checks),
             'multiPremiseChecks':sum(len(b.get('conditions',[]))>1 for x in checks for b in x['feedback'].get('branches',[])),
             'reusedBranches':sum(bool(b.get('reusedComponents')) for x in checks for b in x['feedback'].get('branches',[])),
             'unknownBranches':sum(b['status']=='unknown' for x in checks for b in x['feedback'].get('branches',[])),
             'rawFeedbackBytes':size_raw,'exposedFeedbackBytes':size_exposed,'providerErrors':sum(bool(c['error']) or c['status']!='completed' for c in calls),
             'runtimeInteractionSha256':plan['runtimeInteractionSha256'],'librarySha256':plan['librarySha256']}
        checked=0;wrong=0;case=plan['case']
        for x in checks:
            if 'exposedFeedback' in x and decode_historical(x['exposedFeedback'])!=x['feedback']:
                raise ValueError('feedback was not lossless: '+folder.name)
            sources=case['changed'] if x['stage']==2 else case['sources'];s={r['name']:r['rows'] for r in sources}
            if case['family']=='context-balanced-paths':
                pairs=balanced_oracle(sources);truth={'balanced':pairs,'bridged':{(c,a,y) for c,a,z in pairs for z2,y in s['bridge'] if z==z2}}
            else:
                flow,permit=tagged_oracle(sources);truth={'flow':flow,'permit':permit}
            for b in x['feedback'].get('branches',[]):
                conditions=b.get('conditions',[{'operation':b.get('operation'),'arguments':b.get('arguments',[])}])
                if b['status']=='unknown' or any(c.get('operation') not in truth for c in conditions):continue
                checked+=1;expected=all(tuple(c['arguments']) in truth[c['operation']] for c in conditions)
                if (b['status']=='supported')!=expected:
                    wrong+=1;disagreements.append({'run':folder.name,'call':x['providerCall'],'branch':b})
        row.update(independentLocalChecks=checked,incorrectLocalChecks=wrong);results.append(row)
        for stage in range(3):
            current=[c for c in calls if c['stage']==stage]
            stage_costs.append({'run':folder.name,'stage':stage,'thinking':sum(count_thinking(c) or 0 for c in current),
                                'calls':len(current),'firstCorrectCall':first[stage],'failedFinalAnswers':sum(not v['correct'] and v['stage']==stage for v in data['verdicts'])})
        for p in folder.glob('*-provider.json'):
            metadata=json.loads(p.read_text());terminal=metadata.get('terminal') or {};key=terminal.get('id') or sha(p)
            audit.setdefault(key,{'responseId':terminal.get('id'),'status':terminal.get('status'),'usage':terminal.get('usage'),
                                 'error':metadata.get('error'),'seconds':metadata['providerSeconds'],'files':[]})['files'].append(str(p.relative_to(root)))
        for p in folder.glob('*-request.json'):
            stem=p.name.removesuffix('-request.json')
            if not (folder/(stem+'-provider.json')).exists() and (folder/(stem+'-provider.events.jsonl')).exists():partial.append(str(p.relative_to(root)))
    if disagreements:raise ValueError('incorrect native evidence detected')
    for n,value in [('records',records),('plans',plans),('results',results),('provider-audit',list(audit.values())),('stage-costs',stage_costs),('partial-requests',partial)]:
        (out/(n+'.json')).write_text(json.dumps(value,indent=2)+'\n')
    by_run={r['run']:r for r in results}
    table=['| Task | Old retained interface | Readable fresh | Readable retained | Old → retained reduction | Fresh → retained reduction |',
           '|------+------------------------+----------------+-------------------+--------------------------+----------------------------|']
    baseline_total=0;fresh_total=0;retained_total=0
    for family in ('balanced','mutual'):
        a=by_run['baseline-'+family];b=by_run['readable-'+family+'-fresh'];c=by_run['readable-'+family+'-retained']
        if not all(x['finished'] and x['wholeTaskCorrect'] and x['thinkingComplete'] for x in (a,b,c)):raise ValueError('primary comparisons must be complete')
        baseline_total+=a['thinkingObserved'];fresh_total+=b['thinkingObserved'];retained_total+=c['thinkingObserved']
        table.append(f'| {family} | {a["thinkingObserved"]} | {b["thinkingObserved"]} | {c["thinkingObserved"]} | {100*(1-c["thinkingObserved"]/a["thinkingObserved"]):.2f}% | {100*(1-c["thinkingObserved"]/b["thinkingObserved"]):.2f}% |')
    table.append(f'| Total | {baseline_total} | {fresh_total} | {retained_total} | {100*(1-retained_total/baseline_total):.2f}% | {100*(1-retained_total/fresh_total):.2f}% |')
    physical_thinking=sum((x.get('usage') or {}).get('output_tokens_details',{}).get('reasoning_tokens',0) for x in audit.values())
    title=['#+title: Path Consumption, Evidence Reuse, and Whole-Task Reasoning Cost','# SPDX-FileCopyrightText: 2026 tao3k team and Contributors','# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later']
    report=title+['','* Questions and verified root causes','',
      'The previous study observed correct Scheme evidence followed by omitted supported candidates and increased whole-task thinking. This study asks why the interface did not expose useful candidate-path continuation and whether repairing it preserves quality while reducing actual cumulative reasoning. Findings are bounded to the recorded tasks and provider observations.',
      '', 'Three concrete design defects were addressed: (1) a generic operation/arguments interface advertised conjunction only as an optional alternative; (2) per-branch provenance repeated large fingerprints and source identities, producing approximately 118 KB for 108 checks; (3) native component reuse was not exposed as a convenient model-side path reference and extension operation. These are confirmed interface properties, not a proof of what caused every model decision.',
      '', 'The initial corrective column encoding introduced another defect. The provider-visible reasoning in new-mutual-retained/stage-0-call-1 interpreted the Boolean present array as potentially indicating that every condition was true. It then queried individual flow states again. The raw record retains the complete observation; this report does not treat visible reasoning as a certified reconstruction of all internal cognition. The final interface eliminates the Boolean mask and exposes explicit branch id/status/reference/conditions objects with shared provenance.',
      '', 'An independent old-interface baseline in the new corpus voluntarily used four-premise branches. Therefore the earlier non-use was not an intrinsic inability to express conjunction, and the optional-field design is not established as the sole cause. Tool-call records, sampling variation, question interpretation and feedback clarity must be considered together.',
      '', '* Implemented Library contract','',
      'EvidenceInteraction registers trusted local domain operations. check_branches advertises candidate paths as required lists of model-selected prerequisites. reuse_paths rechecks an existing local path without retyping conditions. extend_paths combines the original path prerequisites with additional model-selected conditions. Source replacement clears references and retained certificates. Scheme evaluates conjunctions and admits source-bound reuse; Python transports arguments and factors repeated metadata. No registered program is a model-written whole-question query.',
      '', 'The model receives capability schemas and domain definitions, not a task-specific solution recipe. There are no few-shot solved paths, final-query rules, gold answers, forced tool selection, or required tool sequence in model requests. tool_choice remains auto, strict remains false. All provider reasoning output items and paired tool results are preserved. A complete local predicate check never proves that all necessary conditions for the original natural-language task were selected.',
      '', 'Readable feedback uses ascent.path-feedback.v1. Every path status is an explicit object field; sharedEvidence applies to branches in that group. Unknown remains unknown, including invalid references and unsupported domain operations. No field is omitted from the auditable expanded packet. The 108-branch fixture contracts from 112073 to 32646 serialized bytes, with exact round-trip equality. This is a context-format measurement, not a reasoning-token saving claim.',
      '', '* Corpus, source, and scientific scope','',
      'Two new independent tasks use seeds 2026106501 and 2026106502, distinct from the prior study. The first has context-specific balanced paths: matching opening/closing labels, recursive concatenation, supplied epsilon, scoped denied edges, and a changed-source goal involving a bridge. The second has mutually recursive flow/permission, tag-specific blocks, conversions and grants. Each includes 40 opaque job candidates. Structural complexity, all finite sources, the three goal sentences and independent oracle answers are retained in questions.org.',
      '', 'Every task has three obligations: the original question, a same-intent paraphrase over unchanged sources, and a changed-source question. An answer to the changed-source question cannot repair an earlier-source obligation. A correct answer to the declared identical paraphrase can repair an earlier failure on that exact finite contract. No arbitrary natural-language equivalence theorem is claimed.',
      '', 'Task design follows the repository\'s scoped inference and provenance research, with recursive relational semantics grounded in Datafun/Ascent and reasoning/tool interleaving motivated by ReAct. It is not a reproduction of a published benchmark. Random opaque instances reduce direct instance memorization but do not establish training exclusion. A fully mechanized evaluator could solve these finite tasks without a model; the experiment measures model use and composition of external checked evidence.',
      '', '* Protocol and matched controls','',
      'Old-interface retained baselines are executed from a frozen host-package snapshot. The first actual response for each new task is replayed identically into new-interface fresh and retained policies. Original question bytes are checked for equality. Every policy charges all first-response thinking, while physical request accounting deduplicates the provider response ID. The same frozen native artifact and independent oracle are used throughout.',
      '', 'The first corrective column-format pilot is retained separately. After observing its encoding ambiguity, four final readable-interface trajectories were run. This is an adaptive engineering experiment over two instances, not a preregistered efficacy estimate or a large-sample confidence result. The old-to-new retained comparison changes schema, reference capabilities and feedback layout together. The readable fresh-to-retained comparison isolates the native retention policy more narrowly, but subsequent model sampling still differs.',
      '', 'Provider: deepseek-flash, high reasoning effort, streaming Responses, max_output_tokens=131072; eight calls and three failed final answers per stage. Usage is actual provider output_tokens_details.reasoning_tokens. Whole-task first correctness includes initial inference, all tool rounds, every failure, paraphrase, and source-change rechecking. Repair cost counts calls after a failed independently graded answer; the failed call itself remains in the whole-task prefix. Output-token totals already include reasoning and must not be added to reasoning a second time.',
      '', '* Primary whole-task results','']+table+['',
      'All six primary trajectories completed all three obligations: 2/2 tasks and 6/6 obligations per policy. No primary final-answer failures occurred, so primary failed-answer repair costs were zero. An already observed real failure is examined separately below. The aggregate old-to-readable-retained reduction reaches the proposed 40–50% range in this two-instance sample; stable population savings are not established.',
      '', f'Interface-only fresh thinking totals {fresh_total}, compared with old retained {baseline_total}: {100*(1-fresh_total/baseline_total):.2f}% lower overall. However, balanced fresh increased from 48683 to 52501 (+7.84%). A clearer interface alone is not a guarantee of lower cost. Readable retained reduces thinking by 39.33% relative to readable fresh in aggregate. These distinct comparisons must not be combined into one causal claim.',
      '', '* Actual mechanism adoption','',
      'Tool logs establish observable multi-premise path checks and explicit reuse_paths calls in the final trajectories. The shared mutual first response already declared four prerequisites per candidate in the old interface, so its adoption cannot be credited to the new schema. New readable trajectories use short-reference rechecks instead of repeatedly sending every prerequisite. This is observable tool use; it does not prove that a returned observation was correctly consumed internally.',
      '', 'extend_paths is implemented and tested through actual native execution, including rejection when a parent is invalidated or a new prerequisite fails. No final real-model trajectory invoked it. The report does not claim that extension improved model efficacy.',
      '', '* Whole-task cost and latency for every run','',
      '| Run | Calls | Accepted goals | Thinking | Failed final answers | Repair thinking | Provider seconds | Native check seconds | Reuse tool calls |',
      '|-----+-------+----------------+----------+----------------------+-----------------+------------------+----------------------+------------------|']
    for r in results:report.append(f'| {r["run"]} | {r["calls"]} | {r["acceptedObligations"]}/3 | {r["thinkingObserved"]} | {r["failedFinalAnswers"]} | {r["repairThinking"]} | {r["providerSeconds"]:.2f} | {r["nativeToolSeconds"]:.3f} | {r["reuseToolCalls"]} |')
    report+=['','* Real failed-prefix correction','',
      'The actual prior balanced failure omitted two candidates whose required local conditions were already supported. Both repair arms preserve the same complete prefix through that incorrect answer: 115852 thinking tokens, including the 84849-token failed response. Previously checked fragments are revalidated locally; only feedback is supplied, never final candidate answers. The original user question and failure history are preserved.',
      '', 'Readable feedback repair used one new model response, 1418 additional thinking, and completed the entire task at 117270 thinking. The column-feedback control used one new response, 964 additional thinking, and completed at 116816. Readable repair is 454 tokens more expensive in this matched example. Therefore the readable format does not show a repair-cost improvement over the column control here. Both achieve correction; no new repair tool invocation was required. Compared with the earlier three-call repair (15125 additional tokens), both are cheaper observations, but that earlier comparison is adaptive and not a causal format-only result.',
      '', '* Performance diagnosis','',
      'The expensive work was chiefly in provider inference requests and repeated model composition. For the mutual task, old provider seconds were 167.23 and native checks 1.168; readable retained was 97.12 and native checks 1.477. Balanced old provider seconds were 263.91 and native checks 0.924; readable retained was 181.61 and native checks 0.868. More native checks need not mean more thinking. Provider seconds include model serving, network and streaming; they are not a measured GPU compute duration.',
      '', 'The previous load receipt for this native artifact measured validation/load/runtime initialization at 0.521 s and first native describe request at 0.000889 s. That separates this study\'s embedded library initialization from multi-minute model requests. It does not close other consumers\' DSL expansion or macro-load gates. No SDK rebuild, timeout widening, remote CI wait or forced tool-use prompt was used for this intervention.',
      '', '* Independent evidence audit and formal qualification','',
      f'Independent fixed-point oracles audited {sum(r["independentLocalChecks"] for r in results)} exposed supported/contradicted local path verdicts with zero disagreement. This includes replayed and revalidated observations; the count is not a denominator of statistically independent samples. Every final model answer was independently graded against the complete finite result. Unknown outcomes never acquired positive evidence.',
      '', 'Actual ABI and compiled API suites each pass 17 checks, including local conjunction, path recheck, parent-preserving extension, source invalidation, 128-candidate capacity, provider-call binding, first-correct scope, and lossless explicit feedback. Lean compiles laws that aliases cannot refresh stale evidence and extension cannot discard a false parent. Quint explores 10000 traces of 30 steps at seed 13 and rejects six mutants: unknown pruning, observation admission, stale reference, missing condition, stale reuse, and dropped parent. These are trusted-checker abstraction laws and bounded protocol checks, not a proof of the native compiler, arbitrary intent, or model cognition.',
      '', '* Physical provider usage, reproduction, and limits','',
      f'Unique response records in this study: {len(audit)}; known physical thinking: {physical_thinking}; interrupted request streams lacking receipts: {len(partial)}. Shared prefix IDs are deduplicated physically and charged fully to each policy ledger. Repair prefixes from the prior study are included in task cost but not newly incurred expenditure. Cached input tokens and output/input usage are listed independently in results.json; semantic reuse must not be equated with physical prefix caching. No total-dollar saving is inferred.',
      '', 'Artifacts: [[file:questions.org][complete questions and source tables]], [[file:rounds.org][every round and outcome]], [[file:visible-answers.org][visible final answers]], [[file:results.json][machine-readable metrics]], [[file:provider-audit.json][unique provider usage]], and [[file:../../features/path-consumption-qualification.json][source-bound local qualification]]. All .cache/ascent/path-consumption request/terminal/event files remain retained locally. The frozen old host and column-pilot controller preserve the actual alternative implementations. This report is regenerated with python -m agentic_ai_lab_testing.assessment_studies.path_consumption_report.',
      '', 'Main limitations: two independent new instances, one prior real failure, adaptive interface correction, no repeated-sampling confidence interval, no real extension invocation, question-interpretation ambiguity, and complete finite benchmark semantics. Registered domain checks and source authenticity remain application responsibilities. A supported declared path is not proof that the model selected every condition needed by the original problem. The observed aggregate reduction does not establish universal or stable 40–50% savings.']
    (out/'report.org').write_text('\n'.join(report)+'\n')
    questions=['#+title: Independent Complex Questions and Oracle Source','', 'Gold below is for audit only and is absent from model requests and tool feedback.']
    for c in {p['case']['case']:p['case'] for p in plans.values()}.values():questions+=['','* '+c['case'],'','#+begin_src json',json.dumps(c,indent=2),'#+end_src']
    (out/'questions.org').write_text('\n'.join(questions)+'\n')
    rounds=['#+title: Every Provider Round and Independent Outcome','','| Run | Round | Stage | Thinking | Input / cached input | Output | Provider seconds | Outcome |','|-----+-------+-------+----------+----------------------+--------+------------------+---------|']
    visible=['#+title: Visible Provider Outputs and Final Answer Sets']
    for name,data in records.items():
        visible+=['','* '+name]
        for c in data['calls']:
            verdict=next((v for v in data['verdicts'] if v['providerCall']==c['id']),None)
            outcome='correct' if verdict and verdict['correct'] else 'incorrect' if verdict else 'tool checkpoint'
            usage=c.get('usage') or {};rounds.append(f'| {name} | {c["id"]} | {c["stage"]} | {count_thinking(c)} | {usage.get("input_tokens")} / {usage.get("input_tokens_details",{}).get("cached_tokens")} | {usage.get("output_tokens")} | {c["seconds"]:.3f} | {outcome} |')
            path=cache/name/(c['id']+'-answer.txt')
            visible+=['','** '+c['id'],f'Thinking: {count_thinking(c)}; outcome: {outcome}.','','#+begin_example',path.read_text() if path.exists() else 'Historical prefix: original response directory retained in plan.','#+end_example']
    (out/'rounds.org').write_text('\n'.join(rounds)+'\n');(out/'visible-answers.org').write_text('\n'.join(visible)+'\n')
    shutil.copyfile(cache/'encoding-receipt.json',out/'encoding-receipt.json')
    sources=out/'execution-sources';sources.mkdir(exist_ok=True)
    for name,source in [('raw-baseline-interaction.py',cache/'baseline-host/ascent/interaction.py'),('column-pilot-interaction.py',cache/'column-pilot-interaction.py'),('readable-interaction.rs',root/'rust/ascent-python/src/api/evidence_conversation.rs'),('study.py',root/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/interactive_study.py')]:shutil.copyfile(source,sources/name)
    for p in out.rglob('*.json'):p.with_name(p.name+'.license').write_text('SPDX-FileCopyrightText: 2026 tao3k team and Contributors\nSPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later\n')
    print(json.dumps({'runs':len(results),'physicalResponses':len(audit),'physicalThinking':physical_thinking,'partialRequests':len(partial),'localChecks':sum(r['independentLocalChecks'] for r in results),'baselineThinking':baseline_total,'readableFreshThinking':fresh_total,'readableRetainedThinking':retained_total,'reduction':100*(1-retained_total/baseline_total)}))


if __name__=='__main__':main()
