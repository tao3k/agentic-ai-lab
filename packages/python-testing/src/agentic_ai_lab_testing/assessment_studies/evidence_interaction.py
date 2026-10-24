#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Consumer-test byte IO and records; not a Library orchestration API."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import tarfile
import time
from datetime import datetime, timezone

ROOT = Path.cwd().resolve()
sys.path.insert(0, str(ROOT / 'python/src'))
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key

RUNTIME = ROOT / '.cache/ascent/evidence-interaction/runtime'
KERNEL = ROOT / '.cache/ascent/crosspath-search/snapshot'
SOLVER_TOOLS = [{'type': 'function', 'name': 'expand',
    'description': 'Select and expand exactly one unvisited child of the supplied parent.',
    'parameters': {'type': 'object', 'properties': {'optionId': {'type': 'integer'}},
                   'required': ['optionId'], 'additionalProperties': False}}]
RUBRIC = '''Extract atomic reasoning episodes ONLY from the supplied external model reasoning. Return exact contiguous quotes, zero-based occurrence, a single concluded atom [relation, integer arguments], the ordered premises EXPLICITLY stated in that quote as atoms, and kind derive/reuse/mention/conditional_recheck/uncertain. Relations are edge, path, ready. ready f means both paths of needs row f. Option IDs are not fragment IDs. A derive episode must contain an inference and actual support, not just an asserted result or a reference to evidence. A reuse episode cites an established result without deriving it. Empty premises are allowed for references and uncertainty, but do not invent edges or fill support from source. Alternative edge chains stay different. Changed value/resource checks are conditional_recheck, not source-path repetitions. Use uncertain for ambiguity. A quoted literal fragment ID must agree with the atom; never silently repair a model's wrong ID. Path endpoints and premise numbers must occur in the quote. Extract explicit negative claims too, using polarity false; absence of derivation is not evidence of absence of thinking. You are blind to arm, score and cost, although reasoning can reveal supplied evidence. Do not invent an episode to fill a category. Native source truth is checked independently after extraction. Quotes must occur verbatim. Return every explicit relevant episode you identify; completeness and independent-rater agreement are unvalidated.'''
LABEL_TOOL = {'type': 'function', 'name': 'annotate', 'description': 'Record exact atomic reasoning episodes.',
 'parameters': {'type': 'object', 'properties': {'episodes': {'type': 'array', 'items': {
 'type': 'object', 'properties': {'quote': {'type': 'string'}, 'occurrence': {'type': 'integer'},
 'atom': {'type': 'array', 'items': {'type': ['string', 'integer']}},
 'premises': {'type': 'array', 'items': {'type': 'array', 'items': {'type': ['string', 'integer']}}},
 'polarity': {'type': 'boolean'}, 'kind': {'type': 'string', 'enum': ['derive', 'reuse', 'mention', 'conditional_recheck', 'uncertain']}},
 'required': ['quote', 'occurrence', 'atom', 'premises', 'polarity', 'kind'], 'additionalProperties': False}}},
 'required': ['episodes'], 'additionalProperties': False}}

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))

def sha(data):
    return hashlib.sha256(data).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def fields(pairs):
    return {k: v for k, v in pairs}

class EvidenceEngine:
    def __init__(self, run, judge=False):
        self.trace = [];self.run=run;self.judge=judge
        env = os.environ.copy()
        env['GERBIL_PATH'] = str(RUNTIME)
        env['GERBIL_LOADPATH'] = ':'.join(map(str, [RUNTIME/'lib', ROOT/'.cache/ascent/evidence-store/lib', KERNEL/'.gerbil/lib']))
        env['LIBRARY_PATH'] = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip() + '/lib'
        for k in ('CC', 'CFLAGS', 'CPPFLAGS', 'LDFLAGS', 'CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'NIX_CFLAGS_COMPILE', 'NIX_LDFLAGS', 'DEVELOPER_DIR', 'SDKROOT'):
            env.pop(k, None)
        binary = KERNEL/'.gerbil/bin/crosspath-search' if judge else RUNTIME/'bin/evidence-search'
        self.err = (run / ('judge-stderr.log' if judge else 'scenario-stderr.log')).open('a')
        self.p = subprocess.Popen([str(binary), '-:max-heap=1G,debug=q'], env=env, cwd=ROOT,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.err, text=True, bufsize=1)
        if not judge:
            began=time.monotonic()
            with selectors.DefaultSelector() as selector:
                selector.register(self.p.stdout,selectors.EVENT_READ)
                if not selector.select(20):
                    save(run/'consumer-readiness-failure.json', {'status':'timeout','deadlineSeconds':20,'seconds':time.monotonic()-began})
                    self.close();raise TimeoutError('consumer module-load readiness deadline')
            if json.loads(self.p.stdout.readline())!={'ready':True}:
                self.close();raise ValueError('unexpected consumer readiness response')
            self.trace.append({'request':{'op':'module_load'},'answer':{'ready':True},'seconds':time.monotonic()-began})

    def call(self, **request):
        began = time.monotonic()
        self.p.stdin.write(canonical(request) + '\n'); self.p.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(self.p.stdout, selectors.EVENT_READ)
            if not selector.select(20):
                raise TimeoutError('native RPC deadline')
        line = self.p.stdout.readline()
        if not line:
            raise RuntimeError('native process exited')
        answer = json.loads(line)
        self.trace.append({'request': request, 'answer': answer, 'seconds': time.monotonic()-began})
        if 'error' in answer:
            raise ValueError(answer['error'])
        return answer

    def close(self):
        if self.p.poll() is None:
            self.p.terminate()
            try: self.p.wait(timeout=5)
            except subprocess.TimeoutExpired: self.p.kill(); self.p.wait(timeout=5)
        self.err.close()

    def __enter__(self): return self
    def __exit__(self, kind, failure, _):
        if failure is not None:
            save(self.run/f"native-failure-{'judge' if self.judge else 'consumer'}-{time.time_ns()}.json",
                 {'failure':str(failure),'trace':self.trace})
        self.close()

def judge_init(judge, task):
    return judge.call(op='init', identity=task['id'], arm='baseline', edges=task['edges'], needs=task['needs'], options=task['options'])

def same_check(a, b):
    for key in ('valid', 'cost', 'risk', 'value', 'depth'):
        if a.get(key) != b.get(key): raise ValueError('independent judge disagreement: '+key)

def binding():
    paths = [ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/evidence_interaction.py', ROOT/'t/research/evidence-search.ss',
        ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py', ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py',
        ROOT/'candidate/evidence-store.ss', KERNEL/'.gerbil/bin/crosspath-search', RUNTIME/'bin/evidence-search']
    for folder in [RUNTIME/'lib', ROOT/'.cache/ascent/evidence-store/lib', KERNEL/'.gerbil/lib']:
        paths += [p for p in folder.rglob('*') if p.is_file() and not p.name.endswith('.lock')]
    paths += list((ROOT/'candidate').glob('*.ss'))
    paths += list((ROOT/'program').glob('*.ss'))
    paths += [Path(p) for p in json.loads((RUNTIME/'poo-source-order.json').read_text())]
    return {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p): sha(p.read_bytes()) for p in sorted(set(paths))}

def verify(run, plan):
    if sha((run/'plan.json').read_bytes()) != (run/'plan.sha256').read_text().strip(): raise ValueError('plan drift')
    if sha((run/'qualification.json').read_bytes()) != plan['qualificationSha256']: raise ValueError('qualification drift')
    for name, digest in plan['binding'].items():
        if sha((ROOT/name).read_bytes()) != digest: raise ValueError('producer drift: '+name)

def qualify(run):
    run.mkdir(parents=True, exist_ok=False)
    records = []
    with EvidenceEngine(run) as native, EvidenceEngine(run, True) as judge:
        for case in (0, 1, 2):
            contexts = []; cert_hashes = []
            task = native.call(op='task', case=case); judge_init(judge, task)
            seed = judge.call(op='grade', goal=task['goal'], selection=task['seed'])
            if not seed['valid'] or seed['optimal']: raise ValueError('common seed must be feasible and nonoptimal')
            for arm in ('baseline', 'facts', 'prune'):
                init = native.call(op='init', case=case, arm=arm)
                cert_hashes.append(sha(canonical(init['certificate']).encode()))
                q = native.call(op='next')['context']; contexts.append(q)
                # Fixed probes, not outcome-tuned model policies. Native/independent checker parity.
                for _ in range(12):
                    step = native.call(op='next')
                    if step['done']: break
                    oid = step['context']['unvisitedChildren'][0]['option']['id']
                    event = native.call(op='expand', optionId=oid)
                    same_check(event['prefix'], judge.call(op='inspect', goal=task['goal'], selection=event['child']))
                    same_check(event['evaluation'], judge.call(op='evaluate', goal=task['goal'], selection=event['completion']))
                state = native.call(op='summary')
                if fields(state['nativeStats'])['proof-builds'] != len(init['libraryLifecycle']['records']): raise ValueError('proof rebuilt across branches')
                if arm != 'prune' and state['prunings']: raise ValueError('control unexpectedly pruned')
                native.call(op='init', case=case, arm=arm)
                native.call(op='next')
                try: native.call(op='expand', optionId=9999)
                except ValueError: pass
                else: raise ValueError('invalid action admitted')
            if len(set(cert_hashes)) != 1: raise ValueError('treatments use different proof')
            baseline, facts, pruned = contexts
            fact_packet = facts['evidence']; facts = {k:v for k,v in facts.items() if k!='evidence'}
            if baseline != facts: raise ValueError('Fact-only root context parity failed')
            if pruned['evidence'] != fact_packet: raise ValueError('Fact/pruning evidence parity failed')
            for key in baseline:
                if key != 'unvisitedChildren' and baseline[key] != pruned[key]: raise ValueError('pruning changed task contract')
            # Independent raw-source judge checks every published Session row
            # at each temporal cut; the fixture never supplies the judge's verdict.
            lifecycle=init['libraryLifecycle']
            for record in lifecycle['records']:
                atom_task={**task,'edges':record['edges']};memo={}
                expected={n[0] for n in task['needs'] if independent_atom(judge,atom_task,['ready',n[0]],memo)}
                if {r[0] for r in record['sessionReady']}!=expected:raise ValueError('Session/independent temporal Fact parity failed')
                expected_paths={(a,b) for a in range(12) for b in range(12) if independent_atom(judge,atom_task,['path',a,b],memo)}
                if {tuple(p) for p in record['sessionPaths']}!=expected_paths:raise ValueError('Session/independent full path parity failed')
            native.call(op='init',case=case,arm='baseline')
            if not native.call(op='episode',atom=['path',0,7],premises=[['edge',0,2],['edge',2,4],['edge',4,7]])['supportQualified']:raise ValueError('true explicit chain rejected')
            if native.call(op='episode',atom=['path',0,7],premises=[['edge',1,2],['edge',2,4],['edge',4,7]])['supportQualified']:raise ValueError('wrong chain admitted')
            if native.call(op='episode',atom=['path',0,7],premises=[])['supportQualified']:raise ValueError('assertion counted as derivation')
            records.append({'case':case, 'task':task, 'seedGrade':seed, 'certificateSha256':cert_hashes[0], 'libraryLifecycle':lifecycle,
                'rootContexts':contexts, 'probeParity':True})
        save(run/'qualification-native.json', {'scenario':native.trace, 'judge':judge.trace})
    # Both candidate implementation and original checker kernel remain byte bound.
    for dirname in ('candidate','program'):
        for p in (KERNEL/dirname).glob('*.ss'):
            if p.read_bytes() != (ROOT/dirname/p.name).read_bytes(): raise ValueError('kernel source drift: '+dirname+'/'+p.name)
    save(run/'qualification.json', {'tasks':records, 'rootTaskParity':True, 'nativeProbeJudgeParity':True,
        'judgeSha256':sha((KERNEL/'.gerbil/bin/crosspath-search').read_bytes())})
    print('QUALIFIED', len(records), flush=True)

def freeze(run):
    if (run/'plan.json').exists(): raise ValueError('already frozen')
    qualification=json.loads((run/'qualification.json').read_text())
    plan={'frozenAtUtc':datetime.now(timezone.utc).isoformat(), 'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'tasks':[x['task'] for x in qualification['tasks'] if x['case'] in (0,1)], 'calibration':qualification['tasks'][2]['task'],
        'schedule':[(0,'baseline'),(0,'facts'),(0,'prune'),(1,'prune'),(1,'facts'),(1,'baseline')],
        'model':'deepseek-flash','reasoningEffort':'low','budget':65536,'maxOutputTokens':8192,'maxCalls':32,
        'maxConsecutiveFailures':3,'checkpoints':[16384,32768],'tools':SOLVER_TOOLS,
        'nativeBoundaries':'Explicit module-load readiness and each native RPC have separate 20-second deadlines. One consumer/judge process pair is reused within each calibration/solver batch. Earlier combined-load/RPC failures remain archived; no timeout is widened.',
        'solverInstructions':None,'annotationRubric':RUBRIC,'annotationTool':LABEL_TOOL,'annotationOutputCap':8192,
        'measurementContract':'Fixed one returned solver call per chunk; exact quotes, explicit grounded atoms/premises, literal-ID agreement, independent source truth, identical-premise prior links. All calls, failures, negatives, uncertain and rejected labels retained; no extraction retry. Same-provider extraction is not validated independent cognitive ground truth.',
        'budgetContract':'All provider input + all output, including thinking, cached input and failures. Reasoning tokens are a subset of output. Per-call reservation is serialized UTF8 bytes + 4096 + 128*inputItems, plus 8192 output. Unused reservation remains unused, never savings. Only completed actions ending before common checkpoints contribute to quality/depth.',
        'failureContract':'Known usage retained/charged; no failed action admitted. New call receives same pending branch, at most three consecutive failed calls. Unknown usage stops that phase. No retries or continuation of truncated reasoning. Common controller incumbent survives all failures.',
        'boundary':'Consumer fixture only, outside Library build. Agentic AI Lab revision projection and reverse-dependency plan feed ASCENT retained Session; independent finite proof replay compares its published rows. Each case starts after its predetermined temporal history; this study does not yet test live correction mid-model-dialogue. All arms use native post-choice validation. Baseline has no model-visible Facts or Fact prepruning. Fact-only and pruning share evidence. Two fixed task cases, one run per arm; descriptive only. No general source authentication, MRR integration or causal-mechanism claim.',
        'binding':binding(),'qualificationSha256':sha((run/'qualification.json').read_bytes())}
    save(run/'plan.json',plan); (run/'plan.sha256').write_text(sha((run/'plan.json').read_bytes())+'\n')
    # Exact executable study sources are artifacts, not copied active modules.
    producers=run/'producers'; producers.mkdir()
    for name in plan['binding']:
        if name.endswith('.py') or name in ('t/research/evidence-search.ss','candidate/evidence-store.ss'):
            dest=producers/name; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes((ROOT/name).read_bytes())
        elif name.startswith('/'):
            dest=producers/'agentic-ai-lab'/Path(name).relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(Path(name).read_bytes())
    preview=run/'payload-review';preview.mkdir()
    for entry in qualification['tasks']:
        for arm,context in zip(('baseline','facts','prune'),entry['rootContexts']):
            save(preview/f"case-{entry['case']}-{arm}.json",request_for(plan,context))
    save(preview/'manifest.json',{'destination':'https://api.deepseek.com/responses','data':'Synthetic graph, fixed numerical search task, native Fact/proof nodes. No repository source, user files, business records or credentials in requests.','solverSystemInstructions':False,'solverAntiRepetitionPrompt':False})
    print('FROZEN',sha((run/'plan.json').read_bytes()),flush=True)

def request_for(plan, context):
    return {'model':plan['model'],'input':[{'role':'user','content':canonical(context)}],
        'tools':plan['tools'],'tool_choice':'auto',
        'reasoning':{'effort':plan['reasoningEffort']},'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}

def charge(usage):
    if not isinstance(usage,dict) or any(type(usage.get(k)) is not int or usage[k]<0 for k in ('input_tokens','output_tokens')):
        raise ValueError('unknown_usage')
    total=usage['input_tokens']+usage['output_tokens']
    if usage.get('total_tokens',total)!=total: raise ValueError('inconsistent_usage')
    for field,key,limit in [('output_tokens_details','reasoning_tokens','output_tokens'),('input_tokens_details','cached_tokens','input_tokens')]:
        n=(usage.get(field) or {}).get(key)
        if n is not None and (type(n) is not int or not 0<=n<=usage[limit]):raise ValueError('inconsistent_usage_details')
    return total

def reasoning(meta, path):
    term=meta.get('terminal') or {}
    text='\n'.join(p.get('text','') for item in term.get('output',[]) if item.get('type')=='reasoning' for p in item.get('content',[]) if p.get('type')=='reasoning_text')
    if not text and path.with_suffix('.events.jsonl').exists():
        text=''.join(e.get('delta','') for line in path.with_suffix('.events.jsonl').read_text().splitlines() if (e:=json.loads(line)).get('type')=='response.reasoning_text.delta')
    return text

def phase(run, plan, case, arm, calibration=False, native=None, judge=None):
    folder=run/('calibration' if calibration else 'paid')/f'{case}-{arm}';folder.mkdir(parents=True,exist_ok=False)
    row={'case':case,'arm':arm,'calls':[],'expansions':[],'grossTokens':0,'failure':None,'stopReason':None,'budget':plan['budget']}
    with contextlib.ExitStack() as stack:
        native=native or stack.enter_context(EvidenceEngine(run));judge=judge or stack.enter_context(EvidenceEngine(run,True))
        init=native.call(op='init',case=case,arm=arm);task=init['task'];judge_init(judge,task)
        save(folder/'certificate.json',init['certificate']);save(folder/'library-lifecycle.json',init['libraryLifecycle']);row['seedGrade']=judge.call(op='grade',goal=task['goal'],selection=task['seed'])
        consecutive=0
        for turn in range(1 if calibration else plan['maxCalls']):
            step=native.call(op='next')
            if step['done']:row['stopReason']='tree_exhausted';break
            request=request_for(plan,step['context']);reserve=len(canonical(request).encode())+4096+128*len(request['input'])
            if row['grossTokens']+reserve+plan['maxOutputTokens']>plan['budget']:
                row['stopReason']='remaining_below_input_output_reservation';break
            save(folder/f'{turn}.request.json',request);response=folder/f'{turn}.response.json'
            _,meta=provider(request,provider_key(),response);term=meta.get('terminal') or {};text=reasoning(meta,response)
            (folder/f'{turn}.thinking.txt').write_text(text)
            call={'turn':turn,'status':term.get('status'),'usage':term.get('usage'),'failure':None,
                'providerSeconds':meta.get('providerSeconds'),'thinkingSha256':sha(text.encode()),'inputReserve':reserve}
            row['calls'].append(call)
            try:
                call['grossTokens']=charge(call['usage']);row['grossTokens']+=call['grossTokens'];call['atGrossTokens']=row['grossTokens']
                if call['usage']['input_tokens']>reserve or call['usage']['output_tokens']>plan['maxOutputTokens'] or row['grossTokens']>plan['budget']:
                    raise ValueError('budget_violation')
            except ValueError as error:
                call['failure']=str(error);row['failure']=str(error);row['stopReason']='unqualified_cost';save(folder/'receipt.json',row);break
            try:
                if meta.get('error') or term.get('status')!='completed':raise ValueError('provider_incomplete_or_error')
                actions=[x for x in term.get('output',[]) if x.get('type')=='function_call']
                if len(actions)!=1 or actions[0].get('name')!='expand':raise ValueError('expected_one_expand')
                args=json.loads(actions[0]['arguments'])
                if set(args)!={'optionId'} or type(args['optionId']) is not int:raise ValueError('invalid_action_schema')
                event=native.call(op='expand',**args)
                same_check(event['prefix'],judge.call(op='inspect',goal=task['goal'],selection=event['child']))
                same_check(event['evaluation'],judge.call(op='evaluate',goal=task['goal'],selection=event['completion']))
                event.update(turn=turn,atGrossTokens=row['grossTokens']);row['expansions'].append(event);consecutive=0
            except (ValueError,KeyError,TypeError) as error:
                call['failure']=str(error);consecutive+=1
                if 'disagreement' in str(error):row['failure']=str(error);row['stopReason']='judge_disagreement';break
                if consecutive>=plan['maxConsecutiveFailures']:row['failure']='consecutive_failed_calls';row['stopReason']='failed_calls';break
            save(folder/'receipt.json',row)
            print('\nSOLVER',case,arm,turn,'gross',row['grossTokens'],'failure',call['failure'],flush=True)
        state=native.call(op='summary');row['state']=state
        row['grade']=judge.call(op='grade',goal=task['goal'],selection=state['incumbent']['selection'])
        same_check(state['incumbent']['evaluation'],row['grade'])
        row['unusedBudget']=plan['budget']-row['grossTokens'];row['stopReason']=row['stopReason'] or ('calibration_one_call' if calibration else 'call_limit')
        save(folder/'native.json',{'scenario':native.trace,'judge':judge.trace});save(folder/'receipt.json',row)
    print('\nPHASE',case,arm,len(row['calls']),row['grossTokens'],'gap',row['grade']['gap'],flush=True)
    return row

def calibrate(run,plan):
    verify(run,plan);rows=[]
    with EvidenceEngine(run) as native,EvidenceEngine(run,True) as judge:
        for arm in ('baseline','facts','prune'):
            rows.append(phase(run,plan,2,arm,True,native,judge));save(run/'calibration-ledger.json',{'phases':rows,'passed':False})
    passed=all(len(r['expansions'])==1 and r['calls'][0]['status']=='completed' and not r['calls'][0]['failure'] for r in rows)
    save(run/'calibration-ledger.json',{'phases':rows,'passed':passed})
    if not passed:raise ValueError('calibration gate failed; no confirmatory study')
    print('CALIBRATION_PASSED',flush=True)

def solve(run,plan):
    verify(run,plan)
    if not json.loads((run/'calibration-ledger.json').read_text())['passed']:raise ValueError('calibration failed')
    if (run/'ledger.json').exists():raise ValueError('study already started; do not overwrite failures')
    rows=[]
    with EvidenceEngine(run) as native,EvidenceEngine(run,True) as judge:
        for case,arm in plan['schedule']:
            rows.append(phase(run,plan,case,arm,native=native,judge=judge));save(run/'ledger.json',{'planSha256':sha((run/'plan.json').read_bytes()),'phases':rows})
    verify(run,plan);print('SOLVER_STUDY_COMPLETE',flush=True)

def independent_atom(judge,task,atom,memo):
    key=canonical(atom)
    if key in memo:return memo[key]
    if not isinstance(atom,list) or len(atom) not in (2,3) or atom[0] not in ('ready','path','edge') or any(type(x) is not int for x in atom[1:]):
        raise ValueError('malformed label atom')
    if atom[0]=='ready':
        if len(atom)!=2 or not any(n[0]==atom[1] for n in task['needs']):raise ValueError('unknown fragment')
        needs=task['needs'];fragment=atom[1];edges=task['edges']
    else:
        if len(atom)!=3:raise ValueError('wrong path/edge arity')
        fragment=0;needs=[[0,*atom[1:],*atom[1:]]]
        # Direct-edge checking projects literal source records, not transitive inference.
        edges=task['edges'] if atom[0]=='path' else [e for e in task['edges'] if e==atom[1:]]
    options=[{'id':0,'stage':0,'fragment':fragment,'cost':0,'risk':0,'values':[0]}]
    judge.call(op='init',identity=task['id']+'-atomic-check',arm='baseline',edges=edges,needs=needs,options=options)
    checked=judge.call(op='evaluate',goal={'index':0,'stages':1,'costLimit':0,'riskLimit':0,'bonuses':[]},selection=[0])
    memo[key]=checked['valid'];return memo[key]

def anchor(text,quote,occurrence):
    if not isinstance(quote,str) or not quote or type(occurrence) is not int or occurrence<0:raise ValueError('invalid quote occurrence')
    start=0
    for _ in range(occurrence+1):
        pos=text.find(quote,start)
        if pos<0:raise ValueError('quote missing verbatim')
        start=pos+1
    return [pos,pos+len(quote)]

def validate_episode(text,item,task,native,judge,memo):
    span=anchor(text,item['quote'],item['occurrence'])
    if item['kind'] not in ('derive','reuse','mention','conditional_recheck','uncertain') or type(item['polarity']) is not bool:
        raise ValueError('invalid label category')
    atom=item['atom'];premises=item['premises']
    native_check=native.call(op='episode',atom=atom,premises=premises)
    truth=independent_atom(judge,task,atom,memo)
    if truth!=native_check['present']:raise ValueError('atomic independent checker disagreement')
    for premise in premises:
        if not independent_atom(judge,task,premise,memo):raise ValueError('false stated premise')
    numbers={int(x) for x in re.findall(r'(?<![\w.])-?\d+(?![\w.])',item['quote'])}
    # F0 is a literal ID even though its numeric suffix is attached to a letter.
    literal_ids={int(x) for x in re.findall(r'\b(?:F\s*|fragment\s+)(\d+)\b',item['quote'],flags=re.I)}
    literal_ids |= {int(x) for x in re.findall(r'\bready\s*[([]\s*(\d+)\s*[)\]]',item['quote'],flags=re.I)}
    numbers|=literal_ids
    if any(x not in numbers for claim in [atom,*premises] for x in claim[1:]):raise ValueError('claimed endpoints absent from literal quote')
    if atom[0]=='ready' and atom[1] not in literal_ids:raise ValueError('fragment ID absent or mismatched; no silent repair')
    qualified=bool(item['kind']=='derive' and item['polarity'] is True and truth and native_check['supportQualified'])
    return {**item,'span':span,'nativeTruth':truth,'truthMatches':truth==item['polarity'],
        'supportQualified':native_check['supportQualified'],'qualifiedPositiveDerivation':qualified,
        'claimKey':[canonical(atom),canonical(premises),item['polarity']], 'prior':None,'definiteRepeat':False}

def annotate(run,plan):
    verify(run,plan);dest=run/'annotations';dest.mkdir(exist_ok=False);phases=[]
    for row in json.loads((run/'ledger.json').read_text())['phases']:
        folder=run/'paid'/f"{row['case']}-{row['arm']}";task=next(t for t in plan['tasks'] if t['id']==f"evidence-search-{row['case']}")
        measurement={'case':row['case'],'arm':row['arm'],'calls':[],'accepted':[],'rejected':[],'grossTokens':0,'failure':None}
        memo={}
        with EvidenceEngine(run) as native,EvidenceEngine(run,True) as judge:
            native.call(op='init',case=row['case'],arm='baseline')
            for call in row['calls']:
                text=(folder/f"{call['turn']}.thinking.txt").read_text();assert sha(text.encode())==call['thinkingSha256']
                blind=sha((task['id']+'\n'+text).encode())[:24];out=dest/f"{blind}-{len(phases)}-{call['turn']}";out.mkdir(exist_ok=False)
                result={'turn':call['turn'],'atGrossTokens':call.get('atGrossTokens'),'textSha256':sha(text.encode()),
                    'blindId':out.name,'failure':None,'accepted':[],'rejected':[],'grossTokens':0}
                if not text:result['failure']='no_returned_reasoning'
                else:
                    request={'model':plan['model'],'input':[{'role':'user','content':canonical({'edges':task['edges'],'needs':task['needs'],'reasoningText':text})}],
                        'instructions':plan['annotationRubric'],'tools':[plan['annotationTool']],'tool_choice':{'type':'function','name':'annotate'},
                        'reasoning':{'effort':'none'},'max_output_tokens':plan['annotationOutputCap'],'stream':True,'store':False}
                    save(out/'request.json',request);_,meta=provider(request,provider_key(),out/'response.json');term=meta.get('terminal') or {}
                    result['usage']=term.get('usage');result['providerSeconds']=meta.get('providerSeconds')
                    try:
                        result['grossTokens']=charge(result['usage']);measurement['grossTokens']+=result['grossTokens']
                        if meta.get('error') or term.get('status')!='completed':raise ValueError('annotation_incomplete_or_error')
                        actions=[x for x in term.get('output',[]) if x.get('type')=='function_call' and x.get('name')=='annotate']
                        if len(actions)!=1:raise ValueError('expected_one_annotation_action')
                        raw=json.loads(actions[0]['arguments'])['episodes'];result['rawEpisodes']=raw
                        for i,item in enumerate(raw):
                            try:
                                episode=validate_episode(text,item,task,native,judge,memo)
                                episode.update(index=len(measurement['accepted']),turn=call['turn'],textSha256=result['textSha256'],atGrossTokens=call.get('atGrossTokens'))
                                if result['accepted'] and episode['span'][0]<result['accepted'][-1]['span'][0]:raise ValueError('out_of_order_quote')
                                previous=next((p for p in measurement['accepted'] if p['qualifiedPositiveDerivation'] and p['claimKey']==episode['claimKey'] and
                                    (p['turn']<episode['turn'] or p['span'][1]<=episode['span'][0])),None)
                                if episode['qualifiedPositiveDerivation'] and previous:
                                    episode['prior']={'turn':previous['turn'],'index':previous['index']};episode['definiteRepeat']=True
                                result['accepted'].append(episode);measurement['accepted'].append(episode)
                            except (ValueError,KeyError,TypeError,IndexError) as error:
                                rejection={'turn':call['turn'],'rawIndex':i,'item':item,'reason':str(error)}
                                result['rejected'].append(rejection);measurement['rejected'].append(rejection)
                    except (ValueError,KeyError,TypeError) as error:result['failure']=str(error)
                if result['failure']:measurement['failure']='one_or_more_missing_measurements'
                save(out/'receipt.json',result);measurement['calls'].append(result)
                save(dest/f"phase-{row['case']}-{row['arm']}.json",measurement)
                print('\nANNOTATION',row['case'],row['arm'],call['turn'],'labels',len(result['accepted']),'rejected',len(result['rejected']),'failure',result['failure'],flush=True)
            save(dest/f"native-{row['case']}-{row['arm']}.json",{'scenario':native.trace,'independentAtomJudge':judge.trace})
        phases.append(measurement);save(run/'annotation-ledger.json',{'planSha256':sha((run/'plan.json').read_bytes()),'phases':phases})
    verify(run,plan);print('ANNOTATION_COMPLETE',flush=True)

def point(row,labels,boundary):
    expansions=[e for e in row['expansions'] if e['atGrossTokens']<=boundary]
    valid=[e for e in expansions if e['evaluation']['valid']]
    covered=[c for c in row['calls'] if c.get('atGrossTokens',float('inf'))<=boundary]
    measurement=[c for c in labels['calls'] if c['turn'] in {x['turn'] for x in covered}]
    accepted=[e for e in labels['accepted'] if e.get('atGrossTokens',float('inf'))<=boundary]
    repeats=sum(e['definiteRepeat'] for e in accepted)
    return {'checkpoint':boundary,'reached':row['grossTokens']>=boundary,
        'value':max([row['seedGrade']['value'],*[e['evaluation']['value'] for e in valid]]),
        'expansions':len(expansions),'validDepth':max([len(e['child']) for e in expansions if e['prefix']['valid']],default=0),
        'uniqueFeasibleCandidates':len({canonical(e['completion']) for e in valid}),
        'positiveRepeatedDerivations':repeats if all(not c['failure'] for c in measurement) and len(measurement)==len(covered) else None,
        'availableRepeatedLabels':repeats,'qualifiedPositiveDerivations':sum(e['qualifiedPositiveDerivation'] for e in accepted),
        'reuseLabels':sum(e['kind']=='reuse' and e['truthMatches'] for e in accepted),
        'uncertainLabels':sum(e['kind']=='uncertain' for e in accepted),
        'repeatsPerExpansion':repeats/len(expansions) if expansions else None,
        'failedMeasurementCalls':sum(bool(c['failure']) for c in measurement)}

def report(run,plan):
    verify(run,plan);solver=json.loads((run/'ledger.json').read_text());ann=json.loads((run/'annotation-ledger.json').read_text());cal=json.loads((run/'calibration-ledger.json').read_text())
    labels={(x['case'],x['arm']):x for x in ann['phases']};table=[];spans=[]
    for row in solver['phases']:
        lab=labels[row['case'],row['arm']];folder=run/'paid'/f"{row['case']}-{row['arm']}"
        assert sum(c.get('grossTokens',0) for c in row['calls'])==row['grossTokens']<=plan['budget']
        for call in row['calls']:
            request=json.loads((folder/f"{call['turn']}.request.json").read_text())
            assert 'instructions' not in request and request['tools']==plan['tools']
            assert sha((folder/f"{call['turn']}.thinking.txt").read_bytes())==call['thinkingSha256']
        for episode in lab['accepted']:
            text=(folder/f"{episode['turn']}.thinking.txt").read_text();assert text[slice(*episode['span'])]==episode['quote']
            spans.append({'case':row['case'],'arm':row['arm'],**episode})
        table.append({'case':row['case'],'arm':row['arm'],'calls':len(row['calls']),'failedCalls':sum(bool(c['failure']) for c in row['calls']),
            'truncatedCalls':sum(c['status']=='incomplete' for c in row['calls']),'grossTokens':row['grossTokens'],'unusedBudget':row['unusedBudget'],
            'thinkingTokens':sum((c['usage'].get('output_tokens_details') or {}).get('reasoning_tokens',0) for c in row['calls'] if isinstance(c.get('usage'),dict)),
            'seedValue':row['seedGrade']['value'],'bestValue':row['grade']['value'],'gap':row['grade']['gap'],'valid':row['grade']['valid'],
            'nativeStats':fields(row['state']['nativeStats']),'automaticPrunedBranches':sum(len(fields(p[1])['pruned']) for p in row['state']['prunings']),
            'measurementFailure':lab['failure'],'rejectedLabels':len(lab['rejected']),
            'checkpoints':[point(row,lab,cp) for cp in plan['checkpoints']]})
    # Assert the common root task and Fact-only/pruning packet parity on real payloads.
    for case in (0,1):
        roots={arm:json.loads(json.loads((run/'paid'/f'{case}-{arm}'/'0.request.json').read_text())['input'][0]['content']) for arm in ('baseline','facts','prune')}
        f=roots['facts'].copy();p=roots['prune'].copy();packet=f.pop('evidence');assert p.pop('evidence')==packet
        assert roots['baseline']==f
        for key in f:
            if key!='unvisitedChildren':assert f[key]==p[key]
    result={'planSha256':sha((run/'plan.json').read_bytes()),'table':table,
        'solverGrossTokens':sum(r['grossTokens'] for r in solver['phases']),
        'calibrationGrossTokens':sum(r['grossTokens'] for r in cal['phases']),
        'measurementGrossTokens':sum(x['grossTokens'] for x in ann['phases']),
        'limitations':['Two deterministic tasks, one stochastic run per arm; descriptive study, not a causal/statistical effect estimate.',
            'All arms retain Scheme execution and post-choice checking. Baseline omits model-visible Fact evidence and Fact prepruning.',
            'Task/action contracts are common; there are no solver system instructions, anti-repetition directives or requested audit narration.',
            'Only actual completed native-admitted prefixes measure depth; full seed-suffix candidates do not establish explored depth.',
            'Unused ceiling is not savings. Matched checkpoints credit only observed completed calls before the common gross-token boundary.',
            'Positive repeated labels require exact quotes, literal IDs/endpoints, independently true atoms and native-qualified explicit edge-chain/conjunction support. This narrow metric omits unsupported/negative/ambiguous derivations.',
            'Same-provider extraction is partially blind but not independently validated for completeness or semantic category accuracy. Counts are qualified labels, not cognitive ground truth.',
            'This is a Library consumer test, not a Library Search/Fact workflow API or MRR integration. Agentic AI Lab revision projection and reevaluation planning are exercised before model calls at fixed cuts; live revision during the model dialogue remains unqualified.',
            'Retained Session publication is checked against independently replayed finite evidence. Proof replay costs are additional; no cross-generation retained-proof algorithm or source authentication is claimed.',
            'Native proof builds/hits are not end-to-end speed or model-thinking savings. Negative and failed outcomes remain in all records.']}
    prior=ROOT/'.cache/ascent/archived-runs/docs/research/agent-inference/history/consumer-calibration-failure.tar.gz'
    if prior.exists():
        result['priorProtocolFailureArchiveSha256']=sha(prior.read_bytes())
        result['priorProtocolCostBoundary']='Earlier HTTP 400 requests returned no usage. Their cost is unknown, not zero; they are excluded from known-token sums and retained in the failure archive.'
    save(run/'report.json',result);save(run/'thinking-episodes.json',spans)
    lines=['# Native Fact interaction study','',f"Frozen plan `{result['planSha256']}`. One implementation; three configured treatments. No solver instructions or anti-repetition prompt.",'',
        '| Task / arm | Gross / unused | Seed → best | Gap | Calls / failures / truncation | Native Fact prunings |',
        '|---|---:|---:|---:|---:|---:|']
    for r in table:lines.append(f"| {r['case']} / {r['arm']} | {r['grossTokens']} / {r['unusedBudget']} | {r['seedValue']} → {r['bestValue']} | {r['gap']} | {r['calls']} / {r['failedCalls']} / {r['truncatedCalls']} | {r['automaticPrunedBranches']} |")
    lines+=['','## Matched input + all-output checkpoints','','| Task / arm | Gross checkpoint / reached | Value | Expansions / admitted depth | Qualified positive repeats / derives / reuse | Missing measurements |','|---|---:|---:|---:|---:|---:|']
    for r in table:
        for cp in r['checkpoints']:lines.append(f"| {r['case']} / {r['arm']} | {cp['checkpoint']} / {cp['reached']} | {cp['value']} | {cp['expansions']} / {cp['validDepth']} | {cp['positiveRepeatedDerivations']} / {cp['qualifiedPositiveDerivations']} / {cp['reuseLabels']} | {cp['failedMeasurementCalls']} |")
    lines+=['',f"Solver gross tokens {result['solverGrossTokens']}; separate calibration {result['calibrationGrossTokens']}; separate measurement {result['measurementGrossTokens']}.",'',*result['limitations']]
    (run/'report.md').write_text('\n'.join(lines)+'\n')
    quotes=['# Source-anchored returned-thinking episodes','']
    for e in spans:quotes += [f"- task {e['case']}, {e['arm']}, call {e['turn']}, atom {e['atom']}, kind {e['kind']}, span {e['span']}, repeat {e['definiteRepeat']}, prior {e['prior']}",'','> '+e['quote'].replace('\n','\n> '),'']
    (run/'thinking-episodes.md').write_text('\n'.join(quotes)+'\n')
    raw={str(p.relative_to(run)):sha(p.read_bytes()) for p in sorted(run.rglob('*')) if p.is_file() and p.name!='integrity.json' and not p.name.endswith('.log')}
    save(run/'integrity.json',{'producerBindingVerified':True,'rootTaskAndEvidenceParity':True,'grossChargesAndLiteralSpansVerified':True,'rawFiles':raw})
    doc=ROOT/'.cache/ascent/research-reports/agent-inference/evidence-interaction-results';doc.mkdir(parents=True,exist_ok=True)
    for name in ('report.json','report.md','thinking-episodes.json','thinking-episodes.md','integrity.json','plan.json','qualification.json','ledger.json','annotation-ledger.json','calibration-ledger.json'):
        (doc/name).write_bytes((run/name).read_bytes())
    bundle=doc/'raw.tar.gz'
    with tarfile.open(bundle,'w:gz') as tar:
        if prior.exists():tar.add(prior,arcname='development/consumer-calibration-failure.tar.gz')
        for dirname in ('paid','calibration','annotations','payload-review','producers'):tar.add(run/dirname,arcname=dirname)
        for name in ('plan.json','plan.sha256','qualification.json','qualification-native.json','ledger.json','annotation-ledger.json','calibration-ledger.json','integrity.json'):tar.add(run/name,arcname=name)
        development=run.parent
        for folder in ('failed-startup-qualification','consumer-startup-probe','consumer-model-check'):
            if (development/folder).exists():tar.add(development/folder,arcname='development/'+folder)
        for folder in ('failed-object-command-resolution','failed-object-runtime-prefix','native-objects','retired-locks'):
            if (RUNTIME/folder).exists():tar.add(RUNTIME/folder,arcname='development/runtime/'+folder)
        for log in sorted(RUNTIME.glob('*.log')):tar.add(log,arcname='development/runtime/'+log.name)
        for name in ('consumer-build.json','poo-source-order.json','native-object-closure.json','native-link-receipt.json','native-link-missing-crypto.json'):
            tar.add(RUNTIME/name,arcname='development/runtime/'+name)
    save(doc/'archive.json',{'sha256':sha(bundle.read_bytes()),'bytes':bundle.stat().st_size})
    print('REPORTED',result['solverGrossTokens'],result['measurementGrossTokens'],flush=True)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['qualify','freeze','calibrate','solve','annotate','report']);parser.add_argument('--run-dir',type=Path,required=True)
    args=parser.parse_args();run=args.run_dir.resolve()
    if args.command=='qualify':qualify(run)
    elif args.command=='freeze':freeze(run)
    else:
        plan=json.loads((run/'plan.json').read_text());globals()[args.command](run,plan)

if __name__=='__main__': main()
