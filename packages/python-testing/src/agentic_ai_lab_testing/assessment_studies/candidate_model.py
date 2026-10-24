#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Small candidate-feedback consumer; uses existing Library and provider IO."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time
import tarfile

ROOT = Path.cwd().resolve()
RUNTIME = ROOT / '.cache/ascent/candidate-interaction/runtime'
PREPARED = ROOT / '.cache/ascent/evidence-interaction/runtime/lib'
CANONICAL = ROOT / '.cache/ascent/candidate-interaction/canonical-runtime/lib'
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def environment():
    env = os.environ.copy()
    env['GERBIL_PATH'] = str(CANONICAL.parent if CANONICAL.exists() else RUNTIME)
    env['GERBIL_LOADPATH'] = f'{CANONICAL}:{PREPARED}' if CANONICAL.exists() else f'{RUNTIME / "lib"}:{PREPARED}'
    for name in ('CC','CFLAGS','CPPFLAGS','LDFLAGS','NIX_CFLAGS_COMPILE','NIX_LDFLAGS','CPATH','SDKROOT'):
        env.pop(name, None)
    return env

class Consumer:
    def __init__(self, run, dynamic=False):
        self.trace = []; self.run = run; self.dynamic = dynamic; self.shutdown = None
        self._stdout_buffer = bytearray()
        run.mkdir(parents=True, exist_ok=True)
        self.err = (run/'native-stderr.log').open('a')
        command = (['/opt/homebrew/bin/gxi', '-e',
                    '(import :gerbil-ascent/t/research/candidate-interaction)', '-e', '(main)']
                   if dynamic else [str(RUNTIME/'bin/candidate-interaction'),'-:max-heap=1G,debug=q'])
        if dynamic == 'module':
            command = [str(RUNTIME/'bin/candidate-interaction'),'-:max-heap=1G,debug=q','--dynamic-evidence']
        try:
            self.p = subprocess.Popen(command,
                env=environment(), cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=self.err, bufsize=0)
        except OSError as error:
            self.err.close()
            save(run/'native-readiness-failure.json', {'phase':'spawn',
                'command':command, 'dynamic':dynamic, 'error':str(error)})
            raise
        began=time.monotonic()
        load_deadline = 60 if dynamic else 20
        try:
            if self.receive(load_deadline) != {'ready':True}: raise ValueError('native readiness mismatch')
            self.trace.append({'request':{'op':'module_load'},'answer':{'ready':True},'seconds':time.monotonic()-began})
            save(run/'native-readiness.json', {'ready':True, 'command':command,
                'dynamic':dynamic, 'deadline':load_deadline, 'seconds':time.monotonic()-began})
        except Exception as error:
            save(run/'native-readiness-failure.json',{'error':str(error),'seconds':time.monotonic()-began,
                'deadline':load_deadline, 'command':command, 'dynamic':dynamic,
                'exit':self.p.poll(), 'pendingBytes':len(self._stdout_buffer)})
            self.close(); raise

    def receive(self, deadline=20):
        expires = time.monotonic() + deadline
        with selectors.DefaultSelector() as selector:
            selector.register(self.p.stdout, selectors.EVENT_READ)
            while b'\n' not in self._stdout_buffer:
                remaining = expires - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    if self._stdout_buffer:
                        (self.run/'native-partial-output.bin').write_bytes(self._stdout_buffer)
                    raise TimeoutError(f'native {deadline}-second deadline')
                chunk = os.read(self.p.stdout.fileno(), 65536)
                if not chunk:
                    if self._stdout_buffer:
                        (self.run/'native-partial-output.bin').write_bytes(self._stdout_buffer)
                    raise RuntimeError(f'native exit before complete response (exit={self.p.poll()})')
                self._stdout_buffer.extend(chunk)
        line, _, rest = self._stdout_buffer.partition(b'\n')
        self._stdout_buffer = bytearray(rest)
        try:
            return json.loads(line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            with (self.run/'native-invalid-output.log').open('ab') as log: log.write(line+b'\n')
            raise

    def call(self, **request):
        began = time.monotonic()
        event={'request':request}
        self.trace.append(event);save(self.run/'native.json',self.trace)
        try:
            self.p.stdin.write((json.dumps(request)+'\n').encode()); self.p.stdin.flush()
            answer = self.receive();event['answer']=answer
        except Exception as error:
            event['failure']=str(error);raise
        finally:
            event['seconds']=time.monotonic()-began;save(self.run/'native.json', self.trace)
        if isinstance(answer, dict) and 'error' in answer: raise ValueError(answer['error'])
        return answer

    def close(self):
        if self.shutdown is not None: return self.shutdown
        began = time.monotonic(); fallback = []; error = None
        if self.p.poll() is None:
            # main already treats stdin EOF as completion. SIGTERM does not
            # reliably wake the dynamic runtime's blocking read-line.
            try: self.p.stdin.close()
            except (BrokenPipeError, OSError) as failure: error = str(failure)
            try: self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                fallback.append('terminate'); self.p.terminate()
                try: self.p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    fallback.append('kill'); self.p.kill(); self.p.wait(timeout=5)
        if not self.p.stdin.closed:
            self.p.stdin.close()
        self.p.stdout.close()
        self.err.close()
        self.shutdown = {'protocol':'stdin EOF', 'dynamic':self.dynamic,
            'clean':self.p.returncode==0 and not fallback and error is None,
            'exit':self.p.returncode, 'fallback':fallback, 'error':error,
            'seconds':time.monotonic()-began, 'graceSeconds':5}
        save(self.run/'native-shutdown.json',self.shutdown)
        return self.shutdown

TASKS = [
    {'case':0,'meaning':'path(x,y) iff a directed walk of positive length exists from x to y. Cycles can derive path(x,x); zero-length walks alone cannot.', 'derived':[['path',2]],'query':['path','?x','?y']},
    {'case':1,'meaning':'path(x,y) iff a directed walk of positive even length exists from x to y. Walks may repeat vertices. Length zero alone is excluded.', 'derived':[['path',2]],'query':['path','?x','?y']},
    {'case':2,'meaning':'path is directed positive-length reachability. both(z) iff there exist x in left and y in right such that path(x,z) AND path(y,z). left contains 0; right contains 1. Walks may repeat vertices.', 'derived':[['path',2],['both',1]],'query':['both','?z']},
]
TOOL = {'type':'function','name':'submit_rules','description':'Submit rules for the supplied fixed Datalog specification.',
    'parameters':{'type':'object','properties':{'rules':{'type':'array','minItems':1,'maxItems':4,
        'items':{'type':'array','minItems':2,'maxItems':5,'items':{'type':'array','minItems':2,'maxItems':3,
            'items':{'type':['string','integer']}}}}},'required':['rules'],'additionalProperties':False}}

def task(case, examples):
    return {**TASKS[case], 'sourceRelations':[['edge',2]]+([['left',1],['right',1]] if case==2 else []),
        'domain':[0,1,2], 'ruleEncoding':'A rule is [headAtom, bodyAtom1, ...]. An atom is [relationName, argument1, ...]. Strings beginning ? are variables. Other argument values are integer constants. All body atoms are positive and conjunctive. Rules are evaluated to their least fixed point using set semantics. Only declared relations are allowed. The host supplies declarations, the fixed query and limits; submit only rules.',
        'examples':[{'edges':r['edges'],'queryRows':r['expected']} for r in examples]}

def request(context):
    return {'model':'deepseek-flash','input':[{'role':'user','content':json.dumps(context,separators=(',',':'))}],
        'tools':[TOOL],'tool_choice':'auto','reasoning':{'effort':'low'},'max_output_tokens':8192,'stream':True,'store':False}

def call_model(folder, context, previous_cost=0):
    folder.mkdir(parents=True, exist_ok=False);req=request(context);save(folder/'request.json',req)
    reservation=len(json.dumps(req).encode())+4096+8192
    if previous_cost+reservation>32768: return {'failure':'budget_reservation','rules':None,'grossTokens':0}
    _,meta=provider(req,provider_key(),folder/'response.json');term=meta.get('terminal') or {}
    thinking='\n'.join(p.get('text','') for x in term.get('output',[]) if x.get('type')=='reasoning'
        for p in x.get('content',[]) if p.get('type')=='reasoning_text')
    (folder/'thinking.txt').write_text(thinking)
    result={'status':term.get('status'),'usage':term.get('usage'),'failure':None,'rules':None,'grossTokens':None}
    try:
        u=result['usage']
        if not isinstance(u,dict) or any(type(u.get(k)) is not int or u[k]<0 for k in ('input_tokens','output_tokens')):
            raise ValueError('unknown_usage')
        result['grossTokens']=u['input_tokens']+u['output_tokens']
        if previous_cost+result['grossTokens']>32768 or u['output_tokens']>8192: raise ValueError('budget_violation')
        if meta.get('error') or term.get('status')!='completed': raise ValueError('incomplete_provider')
        actions=[x for x in term.get('output',[]) if x.get('type')=='function_call']
        if len(actions)!=1 or actions[0].get('name')!='submit_rules': raise ValueError('expected_one_submission')
        args=json.loads(actions[0]['arguments'])
        if set(args)!={'rules'} or not isinstance(args['rules'],list) or not 1<=len(args['rules'])<=4:
            raise ValueError('invalid_submission')
        result['rules']=args['rules']
    except (ValueError,KeyError,TypeError) as error: result['failure']=str(error)
    save(folder/'receipt.json',result)
    return result

def freeze(run):
    run.mkdir(parents=True,exist_ok=False)
    native=Consumer(run)
    try:
        groups=[]
        try:
            for i in range(8):groups.append(native.call(op='qualify',group=i))
            if [g.get('checks') for g in groups] != [64]*7+[0]:
                raise ValueError('native qualification group failed')
            qualification={'checks':sum(g['checks'] for g in groups),
                'staleRejected':groups[7].get('staleRejected'),
                'boundedNotMatch':groups[7].get('boundedNotMatch')}
            if qualification != {'checks':448,'staleRejected':True,'boundedNotMatch':True}:
                raise ValueError('native qualification failed: '+json.dumps(qualification))
            qualified=True
        except ValueError as error:
            qualified=False
            qualification={'admitted':False,'error':str(error),'completedGroups':groups}
            save(run/'correct-control.json',native.call(op='feedback',case=0,
                rules=[[['path','?x','?y'],['edge','?x','?y']],
                       [['path','?x','?z'],['path','?x','?y'],['edge','?y','?z']]]))
        tasks=[task(i,native.call(op='feedback',case=i,rules=[])) for i in range(3)]
    finally: native.close()
    save(run/'qualification.json',qualification)
    paths=[ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/candidate_model.py',ROOT/'t/research/candidate-interaction.ss',
           ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py',ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py',
           ROOT/'t/model/source-closure.ss']
    modules=json.loads((RUNTIME/'closure.json').read_text())['modules']
    if any('agentic-ai-lab' in m for m in modules): raise ValueError('workflow dependency in Library fixture')
    # Resolve only the compiler-reported runtime closure, not unrelated prepared modules.
    system=Path(subprocess.check_output(['/opt/homebrew/bin/gxi','-e','(display (path-expand "lib" (gerbil-home)))'],text=True).strip())
    for module in modules:
        rel=module.lstrip(':').split('~',1)[0]
        found=False
        for lib in [CANONICAL,RUNTIME/'lib',PREPARED,system]:
            prefix=lib/rel
            files=[p for p in prefix.parent.glob(prefix.name+'*') if p.is_file() and not p.name.endswith('.lock')]
            if files: paths+=files;found=True;break
        if not found: raise ValueError('unbound runtime module '+module)
        src=ROOT/(rel.removeprefix('gerbil-ascent/')+'.ss')
        captured=RUNTIME/'current-source'/src.relative_to(ROOT)
        if 't/research/' not in str(src) and captured.exists(): src=captured
        if src.exists():
            paths.append(src)
            relative=src.relative_to(RUNTIME/'current-source') if src.is_relative_to(RUNTIME/'current-source') else src.relative_to(ROOT)
            old=ROOT/'.cache/ascent/crosspath-search/snapshot'/relative
            if 't/research/' not in str(src) and old.exists() and src.read_bytes()!=old.read_bytes():
                receipt_path=RUNTIME/'current-source-build.json'
                receipts=json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
                rebuilt=receipts.get(str(relative),{})
                if rebuilt.get('sourceSha256')!=digest(src) or not rebuilt.get('compiledC'):
                    raise ValueError('prepared source drift '+str(src))
                if rebuilt.get('compiledCSha256')!=digest(Path(rebuilt['compiledC'])):
                    raise ValueError('rebuilt module artifact drift '+str(src))
                if rebuilt['compiledC'] not in json.loads((RUNTIME/'native-object-sources.json').read_text()):
                    raise ValueError('rebuilt source absent from native link '+str(src))
                paths.append(receipt_path)
    paths += [RUNTIME/'bin/candidate-interaction',RUNTIME/'closure.json']
    native_sources=[Path(p) for p in json.loads((RUNTIME/'native-object-sources.json').read_text())]
    for module in modules:
        name=module.replace('/','__')+'.c'
        for static in (CANONICAL/'static',RUNTIME/'lib/static',PREPARED/'static',system/'static'):
            if (static/name).exists() and name not in {p.name for p in native_sources}:
                raise ValueError('runtime submodule omitted from native link: '+module)
    paths += native_sources
    paths += list((RUNTIME/'native-objects').glob('*.o'))
    capture=RUNTIME/'source-capture.json'
    if capture.exists():
        for relative,sha in json.loads(capture.read_text())['sourceSha256'].items():
            captured=RUNTIME/'current-source'/relative
            if digest(captured)!=sha: raise ValueError('captured source drift '+relative)
            paths.append(captured)
        paths.append(capture)
    binding={str(p):digest(p) for p in sorted(set(paths))}
    plan={'tasks':tasks,'tool':TOOL,'binding':binding,'model':'deepseek-flash','budgetPerTrajectory':32768,
        'nativeQualified':qualified,
        'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'librarySourceCapture':json.loads(capture.read_text()) if capture.exists() else None,
        'qualificationSha256':digest(run/'qualification.json'),
        'outputCap':8192,'developmentMasks':[0,1,3,9],'heldOutMasks':[i for i in range(64) if i not in (0,1,3,9)],
        'protocol':'One initial model proposal per task. Only a completed, known-cost proposal failing visible development rows receives one paired revision: same proposal/task, baseline without feedback versus native complete-row feedback. Hidden masks never drive repair. Charge shared initial cost to both trajectories; physical calls count once. No retries, anti-repetition instructions or search controller.',
        'limits':'Finite three-node synthesis/feedback integration gate, not corpus reproduction or proof of reduced thinking. If every development proposal passes, assistance comparison is unexercised. No new formal proof or current-head remote CI claim.'}
    save(run/'plan.json',plan);(run/'plan.sha256').write_text(digest(run/'plan.json')+'\n')
    for path in paths:
        if path.suffix=='.py' or path==ROOT/'t/research/candidate-interaction.ss':
            dest=run/'producers'/path.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(path.read_bytes())
    save(run/'payload-review.json',{'destination':'https://api.deepseek.com/responses','payload':'Synthetic Datalog specifications, four visible graphs and candidate rules. No source files, private records or credentials.', 'requests':[request(t) for t in tasks]})
    print('FROZEN' if qualified else 'FROZEN_NOT_ADMITTED',qualification,digest(run/'plan.json'),flush=True)

def verify(run,plan):
    if digest(run/'plan.json')!=(run/'plan.sha256').read_text().strip(): raise ValueError('plan drift')
    if digest(run/'qualification.json')!=plan['qualificationSha256']: raise ValueError('qualification drift')
    for p,h in plan['binding'].items():
        if digest(Path(p))!=h: raise ValueError('producer drift '+p)

def solve(run):
    plan=json.loads((run/'plan.json').read_text());verify(run,plan)
    if plan.get('nativeQualified') is not True: raise ValueError('native qualification denied; model calls prohibited')
    if (run/'ledger.json').exists(): raise ValueError('already run; retain results')
    native=Consumer(run);rows=[]
    try:
        for t in plan['tasks']:
            i=t['case'];row={'case':i,'initial':{'failure':'not_completed','rules':None,'grossTokens':None},'revisions':[]}
            rows.append(row);save(run/'ledger.json',rows)
            initial=call_model(run/'calls'/f'{i}-initial',t);row['initial']=initial;save(run/'ledger.json',rows)
            if initial['rules'] is not None:
                dev=native.call(op='feedback',case=i,rules=initial['rules']);row['development']=dev
                # Repair is decided by visible data, before any hidden assessment.
                if any(x['status']!='match' for x in dev):
                    for arm in ('baseline','feedback'):
                        context={**t,'candidateRules':initial['rules']}
                        if arm=='feedback':context['executionFeedback']=dev
                        revision=call_model(run/'calls'/f'{i}-{arm}',context,initial['grossTokens'])
                        revised={'arm':arm,'call':revision};row['revisions'].append(revised);save(run/'ledger.json',rows)
                        revised['grade']=native.call(op='grade',case=i,rules=revision['rules']) if revision['rules'] is not None else None
                row['grade']=native.call(op='grade',case=i,rules=initial['rules'])
            save(run/'ledger.json',rows);print('TASK_DONE',i,'failure',initial['failure'],'paired',len(row['revisions']),flush=True)
    except Exception as error:
        row['interactionFailure']=str(error);save(run/'ledger.json',rows)
        save(run/'failure.json',{'case':row['case'],'error':str(error),'remainingTasks':'not run','retry':False})
        print('INTERACTION_STOPPED',row['case'],str(error),flush=True)
    finally: native.close()
    verify(run,plan)
    save(run/'integrity.json',{'bindingVerified':True,'files':{str(p.relative_to(run)):digest(p) for p in sorted(run.rglob('*')) if p.is_file() and p.name!='integrity.json'}})
    doc=ROOT/'.cache/ascent/research-reports/agent-inference/candidate-model-results';doc.mkdir(parents=True,exist_ok=True)
    for name in ['plan.json','qualification.json','ledger.json','integrity.json']:(doc/name).write_bytes((run/name).read_bytes())
    lines=['# Finite Library candidate-feedback model gate','',plan['limits'],'',
           '| Task | Initial held-out matches / evaluated | Complete native attempts | Paired revisions |','|---|---:|---:|---:|']
    for r in rows:
        grade=r.get('grade');matches=f"{sum(x['status']=='match' for x in grade)} / {len(grade)}" if grade is not None else 'not evaluated'
        complete=sum(x['nativeStatus']=='complete' for x in grade) if grade is not None else 'not evaluated'
        lines.append(f"| {r['case']} | {matches} | {complete} | {len(r['revisions'])} |")
    for r in rows:
        if r['initial']['failure'] or r.get('interactionFailure'):lines.append(f"\nTask {r['case']} failure: {r.get('interactionFailure') or r['initial']['failure']}.\n")
    calls=[r['initial'] for r in rows]+[x['call'] for r in rows for x in r['revisions']]
    lines+=['',f"Known physical input + all-output tokens: {sum(c['grossTokens'] or 0 for c in calls)}; unknown-cost calls: {sum(c['grossTokens'] is None for c in calls)}. Unused budget is not savings.", '',
            'Full row differences, rejection/exhaustion, raw provider events, thinking and failures are retained. Only the initial proposal or one frozen development-driven revision is evaluated. No repeated-thinking reduction or search-depth benefit is claimed.']
    (doc/'report.md').write_text('\n'.join(lines)+'\n')
    with tarfile.open(doc/'raw.tar.gz','w:gz') as tar:
        tar.add(run,arcname='run');tar.add(RUNTIME,arcname='runtime')
        if CANONICAL.exists():tar.add(CANONICAL.parent,arcname='canonical-runtime')
        if (run.parent/'canonical-source').exists():tar.add(run.parent/'canonical-source',arcname='canonical-source')
        for failure in sorted(run.parent.glob('failed-*')):
            if failure.is_dir():tar.add(failure,arcname=failure.name)
        for log in run.parent.glob('*.log'):tar.add(log,arcname='logs/'+log.name)
        for receipt in run.parent.glob('*.json'):tar.add(receipt,arcname='receipts/'+receipt.name)
    save(doc/'archive.json',{'sha256':digest(doc/'raw.tar.gz'),'bytes':(doc/'raw.tar.gz').stat().st_size})
    print('COMPLETE',len(rows),flush=True)

# Bounded consumer experiment only. Library owns computational evidence;
# this host fixture owns the search objective and the independent judge.
def study_annotations():
    import importlib.util
    spec=importlib.util.spec_from_file_location('existing_annotation_io',ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/evidence_interaction.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def reachable(edges,a,b):
    pending=[v for u,v in edges if u==a];seen=set()
    while pending:
        v=pending.pop()
        if v==b:return True
        if v not in seen:seen.add(v);pending += [y for x,y in edges if x==v]
    return False

def ready(task,f):
    n=next(n for n in task['needs'] if n[0]==f)
    return reachable(task['edges'],n[1],n[2]) and reachable(task['edges'],n[3],n[4])

def search_task(case):
    import random
    rng=random.Random(713+case)
    edges=[[0,2],[1,3],[2,4],[3,4],[0,5],[5,4],[4,6],[6,7],[8,9],[9,11],[8,10],[10,11],[12,13],[13,14]]
    if case:edges.remove([9,11])
    needs=[[i,*pair] for i,pair in enumerate([(0,7,8,11),(1,7,8,11),(2,7,10,11),(3,7,8,11),
        (0,7,9,11),(1,7,10,11),(12,14,0,7),(12,14,8,11),(7,0,8,11),(0,7,11,8),(0,14,8,11),(12,14,7,0)])]
    options=[]
    for stage in range(8):
        options.append({'id':stage*4,'stage':stage,'fragment':stage%4,'cost':1,'risk':1,'value':9+stage%3})
        for j in (1,2,3):options.append({'id':stage*4+j,'stage':stage,'fragment':rng.randrange(12),'cost':rng.randrange(3,10),'risk':rng.randrange(1,7),'value':rng.randrange(22,64)})
    bonuses=[{'pair':[a*4+rng.randrange(1,4),z*4+rng.randrange(1,4)],'value':rng.randrange(16,41)} for a,z in [(0,3),(1,5),(2,6),(3,7),(0,7),(2,5),(4,6),(1,4)]]
    return {'id':f'library-crosspath-{case}','edges':edges,'needs':needs,'options':options,'stages':8,
        'costLimit':31,'riskLimit':21,'bonuses':bonuses,'seed':[i*4 for i in range(8)],
        'semantics':'path(a,b) is positive-length directed reachability. need(f,a,b,c,d) makes ready(f) true iff path(a,b) and path(c,d). A solution selects exactly one option per stage; each selected fragment must be ready. Sum cost and risk must fit the limits. Maximize sum value plus bonuses whose two option IDs are both selected.'}

def judge_selection(task,selection,complete=False):
    options={x['id']:x for x in task['options']}
    if not isinstance(selection,list) or any(type(i) is not int or i not in options for i in selection):return {'valid':False,'reason':'invalid_ids'}
    chosen=[options[i] for i in selection]
    if any(x['stage']!=i for i,x in enumerate(chosen)) or len(chosen)>task['stages']:return {'valid':False,'reason':'stage_order'}
    cost=sum(x['cost'] for x in chosen);risk=sum(x['risk'] for x in chosen)
    valid=cost<=task['costLimit'] and risk<=task['riskLimit'] and all(ready(task,x['fragment']) for x in chosen)
    return {'valid':valid and (not complete or len(chosen)==task['stages']),'cost':cost,'risk':risk,'depth':len(chosen),
        'value':sum(x['value'] for x in chosen)+sum(x['value'] for x in task['bonuses'] if set(x['pair'])<=set(selection))}

def optimum(task):
    import itertools
    best={'selection':task['seed'],'evaluation':judge_selection(task,task['seed'],True)};checked=0
    for selection in itertools.product(*[[x['id'] for x in task['options'] if x['stage']==s] for s in range(task['stages'])]):
        result=judge_selection(task,list(selection),True);checked+=1
        if result['valid'] and result['value']>best['evaluation']['value']:best={'selection':list(selection),'evaluation':result}
    return {**best,'enumerated':checked}

def reuse_freeze(run):
    run.mkdir(parents=True,exist_ok=False);annotation=study_annotations();tasks=[search_task(i) for i in range(2)];checks=[]
    reference=ROOT/'.cache/ascent/archived-runs/docs/research/agent-inference/fact-reuse-results/plan.json'
    prior=json.loads(reference.read_text())
    assert tasks==prior['tasks'] and annotation.RUBRIC==prior['annotationRubric'] and annotation.LABEL_TOOL==prior['annotationTool'],'frozen task or annotation rule changed'
    original=ROOT/'.cache/ascent/candidate-interaction/reuse-study/producers/tools/research/candidate-model.py'
    def judge_code(path):
        return {node.name:ast.dump(node,include_attributes=False) for node in ast.parse(path.read_text()).body
                if isinstance(node,ast.FunctionDef) and node.name in ('reachable','ready','search_task','judge_selection','optimum')}
    assert judge_code(Path(__file__))==judge_code(original),'independent selection judge changed'
    store_test=ROOT/'.cache/ascent/candidate-interaction/latest-proof-frame-qualification/evidence-store-test.json'
    assert json.loads(store_test.read_text())['passed']
    modules=json.loads((RUNTIME/'closure.json').read_text())['modules']
    assert not any('agentic-ai-lab/' in m for m in modules), 'workflow dependency in consumer'
    linked={Path(p).name for p in json.loads((RUNTIME/'native-object-sources.json').read_text())}
    for module in modules:
        name=module.replace('/','__')+'.c'
        for static in (CANONICAL/'static',PREPARED/'static'):
            assert not (static/name).exists() or name in linked, 'unlinked runtime module '+module
    capture=json.loads((RUNTIME/'source-capture.json').read_text())
    for name,h in capture['sourceSha256'].items():
        assert digest(ROOT/name)==h==digest(RUNTIME/'current-source'/name), 'source capture drift '+name
    for i,t in enumerate(tasks):
        seed=judge_selection(t,t['seed'],True);best=optimum(t);assert seed['valid'] and seed['value']<best['evaluation']['value']
        d=run/f'qualify-{i}';d.mkdir();native=Consumer(d)
        try:
            init=native.call(op='reuse-init',identity=t['id'],edges=t['edges'],needs=t['needs'])
            assert {x[0] for x in init['rows']}=={n[0] for n in t['needs'] if ready(t,n[0])}
            packets=[native.call(op='reuse-packet',fragments=list(range(12))) for _ in range(2)]
            assert packets[0]['facts']==packets[1]['facts'] and packets[0]['nodes']==packets[1]['nodes']
            assert all(p['reused'] for p in packets)
            for p in packets:
                stats=dict(p['stats']);assert stats['proof-builds']==1 and stats['hits']>=1
                for fact in p['facts']:
                    a=fact['atom'];truth=ready(t,a[1]) if a[0]=='ready' else reachable(t['edges'],*a[1:]);assert fact['present']==truth
                assert set(p['allowed'])=={n[0] for n in t['needs'] if ready(t,n[0])}
                ids={n[0] for n in p['nodes']};assert all(x in ids for n in p['nodes'] for x in n[5])
            assert native.call(op='reuse-episode',atom=['path',0,7],premises=[['edge',0,2],['edge',2,4],['edge',4,6],['edge',6,7]])['supportQualified']
            assert not native.call(op='reuse-episode',atom=['path',0,7],premises=[])['supportQualified']
            assert not native.call(op='reuse-episode',atom=['path',0,7],premises=[['edge',1,3]])['supportQualified']
        finally:shutdown=native.close()
        assert shutdown['clean'];checks.append({'case':i,'seed':seed,'optimum':best,'packet':packets[0],'shutdown':shutdown})
    shutdown_dir=ROOT/'.cache/ascent/candidate-interaction/latest-proof-frame-qualification'
    startup=json.loads((shutdown_dir/'receipt.json').read_text())
    assert len(startup)==9 and all(x['passed'] and x['shutdown']['clean'] for x in startup)
    clean={'allClean':True,'checks':startup,'scope':'Native, dynamic evidence module and full gxi, three starts each; current captured proof-frame.'}
    sources=[ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/candidate_model.py',ROOT/'t/research/candidate-interaction.ss',ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/evidence_interaction.py',ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py',ROOT/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py']
    sources += [store_test,ROOT/'candidate/evidence-store.ss',ROOT/'t/qualification/ascent-evidence-store-test.ss',shutdown_dir/'receipt.json']
    sources += [ROOT/'t/research/test_candidate_transport.py',shutdown_dir/'rules/receipt.json',shutdown_dir/'test-receipt.json']
    dialogue=ROOT/'.cache/ascent/candidate-interaction/dialogue-qualification'
    dialogue_receipts=json.loads((dialogue/'receipt.json').read_text())
    assert len(dialogue_receipts)==2 and all(x['status']=='completed' and not x['failure'] for x in dialogue_receipts)
    sources += [reference,original,dialogue/'plan.json',dialogue/'receipt.json']
    turns=ROOT/'.cache/ascent/candidate-interaction/structured-branch-turn-qualification'
    turn_receipts=json.loads((turns/'receipt.json').read_text())
    assert len(turn_receipts)==2 and all(x['status']=='completed' and not x['failure'] and x['action']=={'parentId':i,'optionId':i} for i,x in enumerate(turn_receipts))
    sources += [turns/'plan.json',turns/'receipt.json']
    sources += [p for d in [RUNTIME,CANONICAL.parent] for p in d.rglob('*') if p.is_file() and not p.name.endswith('.lock')]
    binding={str(p):digest(p) for p in sources};save(run/'qualification.json',{'tasks':checks,'shutdown':clean})
    plan={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'librarySourceCapture':capture,'tasks':tasks,'arms':['baseline','facts','scheme'],'orders':[['baseline','facts','scheme'],['scheme','facts','baseline']],
        'unchangedTaskPlanSha256':digest(reference),'independentJudgeAstSha256':hashlib.sha256(json.dumps(judge_code(Path(__file__)),sort_keys=True).encode()).hexdigest(),
        'model':'deepseek-flash','budget':65536,'outputCap':65536,'minimumOutputCap':1024,'inputReservationPadding':256,'maxCalls':24,'checkpoints':[8192,16384,24576,32768,49152,65536],
        'interaction':'Stateless Responses dialogue: replay every returned reasoning/message/function_call item. Pair actual function calls with function_call_output; return observed extension-result data after a strict JSON action message. Request each next extension with the SAME ordinary question as the first turn. API text.format uses exactly the existing expand argument JSON Schema; no user/system instruction is added. Exactly one object with integer parentId/optionId is required in either encoding, followed by unchanged availability and independent semantic checks. No fabricated tool call, repair, fenced-text salvage or retry of incomplete responses. Per-call output is limited only by remaining total budget minus input reservation. Initial input is bounded by serialized request bytes plus 256 framing padding; continuations reserve previous billed input plus output and ALL newly added result/question item bytes plus padding. Observed input must not exceed reservation. All input and output tokens, including cached input and thinking, are charged. Insufficient reservation is censored, not savings.',
        'binding':binding,'qualificationSha256':digest(run/'qualification.json'),
        'annotationRubric':annotation.RUBRIC,'annotationTool':annotation.LABEL_TOOL,'annotationCap':8192,
        'annotationRules':'Use exact quoted thinking, independently true source atoms and explicitly supported edge chains/conjunctions. Mark repeated qualified conclusions within the same immutable source, and separately identical ordered-premise repeats. Different parent paths do not reset prior derivations. Resource/value recalculation, mentions, reuse and uncertainty are excluded. Missing labels are unknown, never zero. No completeness or inter-rater agreement claim.',
        'protocol':'Each arm starts with the same strictly nonoptimal feasible seed and one empty search prefix. Every call chooses one parentId/optionId extension from the supplied frontier. Invalid branches consume cost and are retained. Baseline receives raw task data; facts adds the same relevant verified Fact outcomes used by scheme; scheme adds ancestor-closed proof fragments and Library finite-absence partition. No branch ranking is performed by Scheme. The host independently grades prefixes and complete selections. Unused reservations and call-limit stops are censored, not savings. Compare only jointly reached input-plus-all-output checkpoints. Labeling costs are separate measurement costs.',
        'tool':{'type':'function','name':'expand','description':'Expand one available child from the frontier.','parameters':{'type':'object','properties':{'parentId':{'type':'integer'},'optionId':{'type':'integer'}},'required':['parentId','optionId'],'additionalProperties':False}}}
    save(run/'plan.json',plan);(run/'plan.sha256').write_text(digest(run/'plan.json')+'\n')
    for p in sources[:12]:
        d=run/'producers'/p.relative_to(ROOT);d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(p.read_bytes())
    print('REUSE_FROZEN',digest(run/'plan.json'),flush=True)

def reuse_verify(run):
    plan=json.loads((run/'plan.json').read_text());assert digest(run/'plan.json')==(run/'plan.sha256').read_text().strip()
    assert digest(run/'qualification.json')==plan['qualificationSha256']
    for p,h in plan['binding'].items():assert digest(Path(p))==h,'producer drift '+p
    return plan

def branch_request(plan, context, history, pending_call, spent, history_tokens=None):
    """Provider framing and budget reservation only; no search or truth decisions."""
    if not history:
        inputs=[{'role':'user','content':json.dumps(context,separators=(',',':'))}]
        new_items=inputs
    else:
        # The immutable task and original question remain in the first message.
        # Feed the observed state back as the result of the chosen extension.
        state={k:v for k,v in context.items() if k not in ('task','question')}
        if pending_call is not None:
            new_items=[{'type':'function_call_output','call_id':pending_call,
                        'output':json.dumps(state,separators=(',',':'))},
                       {'role':'user','content':json.dumps({'question':context['question']},separators=(',',':'))}]
        else:
            new_items=[{'role':'user','content':json.dumps({'extensionResult':state,'question':context['question']},separators=(',',':'))}]
        inputs=history+new_items
    req={'model':plan['model'],'input':inputs,'tools':[plan['tool']],'tool_choice':'auto',
         'reasoning':{'effort':'low'},'max_output_tokens':plan['outputCap'],'stream':True,'store':False,
         'text':{'format':{'type':'json_schema','name':'branch_action','schema':plan['tool']['parameters']}}}
    if not history:
        input_bound=len(json.dumps(req,ensure_ascii=False).encode())+plan['inputReservationPadding']
    else:
        assert type(history_tokens) is int and history_tokens>=0,'missing_history_usage'
        # The previous billed input plus output bounds the replayed token text.
        # Reserve new tool-result bytes and framing; do not multiply old thinking
        # tokens by its JSON byte length on every continuation.
        input_bound=history_tokens+sum(len(json.dumps(item,ensure_ascii=False).encode()) for item in new_items)+plan['inputReservationPadding']
    cap=min(plan['outputCap'],plan['budget']-spent-input_bound)
    if cap<plan['minimumOutputCap']:return None,input_bound+plan['minimumOutputCap']
    req['max_output_tokens']=cap
    return req,input_bound+cap

def branch_action(terminal):
    """Decode one untrusted action; semantic admission remains with the judge."""
    outputs=terminal.get('output',[])
    def unique_object(pairs):
        value={}
        for key,item in pairs:
            if key in value:raise ValueError('duplicate_action_key')
            value[key]=item
        return value
    calls=[x for x in outputs if x.get('type')=='function_call']
    if calls:
        assert len(calls)==1 and calls[0].get('name')=='expand','invalid_action'
        call_id=calls[0].get('call_id');assert isinstance(call_id,str) and call_id,'missing_call_id'
        action=json.loads(calls[0]['arguments'],object_pairs_hook=unique_object);encoding='function_call'
    else:
        messages=[x for x in outputs if x.get('type')=='message']
        assert len(messages)==1,'invalid_action'
        parts=messages[0].get('content',[])
        assert parts and all(x.get('type')=='output_text' and isinstance(x.get('text'),str) for x in parts),'invalid_action_content'
        action=json.loads(''.join(x['text'] for x in parts),object_pairs_hook=unique_object);encoding='json_message';call_id=None
    assert isinstance(action,dict) and set(action)=={'parentId','optionId'} and all(type(v) is int for v in action.values()),'invalid_submission'
    return action,encoding,call_id

def reuse_solve(run):
    plan=reuse_verify(run);assert not (run/'reuse-ledger.json').exists();rows=[];save(run/'reuse-ledger.json',rows)
    for case,t in enumerate(plan['tasks']):
        for arm in plan['orders'][case]:
            folder=run/'calls'/f'{case}-{arm}';folder.mkdir(parents=True);native=Consumer(folder)
            row={'case':case,'arm':arm,'calls':[],'grossTokens':0,'maxDepth':0,'expandedPrefixes':[],
                'incumbent':{'selection':t['seed'],'evaluation':judge_selection(t,t['seed'],True)},'stop':None};rows.append(row)
            frontier={0:[]};tried=set();serial=0;history=[];pending_call=None;history_tokens=None
            try:
                native.call(op='reuse-init',identity=t['id'],edges=t['edges'],needs=t['needs'])
                for turn in range(plan['maxCalls']):
                    choices=[]
                    for parent,selection in frontier.items():
                        if len(selection)==t['stages']:continue
                        children=[o for o in t['options'] if o['stage']==len(selection) and (parent,o['id']) not in tried]
                        if children:choices.append({'parentId':parent,'selection':selection,'optionIds':[o['id'] for o in children]})
                    if not choices:row['stop']='frontier_exhausted';break
                    ids=sorted({next(o['fragment'] for o in t['options'] if o['id']==i) for x in choices for i in x['optionIds']})
                    packet=native.call(op='reuse-packet',fragments=ids) if arm!='baseline' else None
                    if arm=='scheme':
                        allowed=set(packet['allowed'])
                        for x in choices:x['optionIds']=[i for i in x['optionIds'] if next(o['fragment'] for o in t['options'] if o['id']==i) in allowed]
                        choices=[x for x in choices if x['optionIds']]
                        if not choices:row['stop']='verified_frontier_exhausted';break
                    context={'task':t,'frontier':choices,'incumbent':row['incumbent'],'question':'Choose one available parentId and optionId to expand while searching for the highest-value feasible complete selection.'}
                    if packet:context['evidence']={'facts':packet['facts']}
                    if arm=='scheme':context['evidence'].update(fragments=packet['fragments'],nodes=packet['nodes'],nodeEncoding=['id','kind','relation','row','ruleLabel','inputs'])
                    req,reserve=branch_request(plan,context,history,pending_call,row['grossTokens'],history_tokens)
                    if req is None:row['stop']='budget_reservation';row['nextReservation']=reserve;break
                    call={'turn':turn,'failure':None,'grossTokens':None,'outputCap':req['max_output_tokens'],'reservation':reserve,'inputReservation':reserve-req['max_output_tokens']};row['calls'].append(call);out=folder/str(turn);out.mkdir();save(out/'request.json',req);save(run/'reuse-ledger.json',rows)
                    _,meta=provider(req,provider_key(),out/'response.json');term=meta.get('terminal') or {};u=term.get('usage');call['usage']=u
                    thinking='\n'.join(p.get('text','') for x in term.get('output',[]) if x.get('type')=='reasoning' for p in x.get('content',[]) if p.get('type')=='reasoning_text');(out/'thinking.txt').write_text(thinking);call['thinkingSha256']=digest(out/'thinking.txt')
                    call['status']=term.get('status');call['incompleteDetails']=term.get('incomplete_details');call['providerError']=meta.get('error')
                    if not isinstance(u,dict) or any(type(u.get(k)) is not int or u[k]<0 for k in ('input_tokens','output_tokens')):raise ValueError('unknown_usage')
                    call['grossTokens']=u['input_tokens']+u['output_tokens'];row['grossTokens']+=call['grossTokens'];call['atGrossTokens']=row['grossTokens']
                    if u['input_tokens']>call['inputReservation']:raise ValueError('input_reservation_violation')
                    if row['grossTokens']>plan['budget'] or u['output_tokens']>req['max_output_tokens']:raise ValueError('budget_violation')
                    if meta.get('error') or term.get('status')!='completed':raise ValueError('incomplete_provider')
                    action,encoding,pending_call=branch_action(term)
                    call['wireEncoding']=encoding
                    history=req['input']+term['output']
                    history_tokens=call['grossTokens']
                    parent=action['parentId'];option=action['optionId'];assert any(x['parentId']==parent and option in x['optionIds'] for x in choices),'unavailable_child'
                    tried.add((parent,option));child=frontier[parent]+[option];evaluation=judge_selection(t,child);call.update(action=action,selection=child,evaluation=evaluation,evidenceStats=packet['stats'] if packet else None)
                    if evaluation['valid']:
                        row['expandedPrefixes'].append(child);row['maxDepth']=max(row['maxDepth'],len(child));serial+=1;frontier[serial]=child
                        if len(child)==t['stages'] and evaluation['value']>row['incumbent']['evaluation']['value']:row['incumbent']={'selection':child,'evaluation':evaluation}
                    call['incumbentValue']=row['incumbent']['evaluation']['value'];call['maxDepth']=row['maxDepth'];save(out/'receipt.json',call);save(run/'reuse-ledger.json',rows)
                    print('REUSE_TURN',case,arm,turn,'gross',row['grossTokens'],'depth',row['maxDepth'],'value',row['incumbent']['evaluation']['value'],flush=True)
                row['stop']=row['stop'] or 'call_limit'
            except Exception as error:
                row['stop']='failure';row['failure']=str(error)
                if row['calls']:
                    row['calls'][-1]['failure']=str(error)
                    save(folder/str(row['calls'][-1]['turn'])/'receipt.json',row['calls'][-1])
            finally:
                row['shutdown']=native.close();row['unusedBudget']=(plan['budget']-row['grossTokens'] if all(c['grossTokens'] is not None for c in row['calls']) else None);save(run/'reuse-ledger.json',rows)
    reuse_verify(run);print('REUSE_MODEL_COMPLETE',flush=True)

class AtomicJudge:
    def call(self,**request):
        if request['op']=='init':
            self.edges=request['edges'];self.needs=request['needs'];self.options=request['options'];return {}
        fragment=next(o['fragment'] for o in self.options if o['id']==request['selection'][0])
        n=next(n for n in self.needs if n[0]==fragment)
        return {'valid':reachable(self.edges,n[1],n[2]) and reachable(self.edges,n[3],n[4])}

class EpisodeConsumer:
    def __init__(self,native):self.native=native
    def call(self,**request):return self.native.call(op='reuse-episode',atom=request['atom'],premises=request['premises'])

def reuse_annotate(run):
    plan=reuse_verify(run);old=study_annotations();rows=json.loads((run/'reuse-ledger.json').read_text());measurements=[]
    assert not (run/'reuse-annotation-ledger.json').exists()
    for row in rows:
        t=plan['tasks'][row['case']];folder=run/'annotations'/f"{row['case']}-{row['arm']}";folder.mkdir(parents=True);native=Consumer(folder);accepted=[];results=[]
        try:
            native.call(op='reuse-init',identity=t['id'],edges=t['edges'],needs=t['needs'])
            for call in row['calls']:
                source=run/'calls'/f"{row['case']}-{row['arm']}"/str(call['turn'])/'thinking.txt';out=folder/str(call['turn']);out.mkdir();result={'turn':call['turn'],'failure':None,'accepted':[],'rejected':[],'grossTokens':None};results.append(result)
                try:
                    text=source.read_text();assert digest(source)==call['thinkingSha256'];assert text,'missing_thinking'
                    req={'model':plan['model'],'input':[{'role':'user','content':json.dumps({'edges':t['edges'],'needs':t['needs'],'reasoningText':text})}],
                        'instructions':plan['annotationRubric'],'tools':[plan['annotationTool']],'tool_choice':{'type':'function','name':'annotate'},'reasoning':{'effort':'none'},'max_output_tokens':plan['annotationCap'],'stream':True,'store':False}
                    save(out/'request.json',req);_,meta=provider(req,provider_key(),out/'response.json');term=meta.get('terminal') or {};u=term.get('usage');result['usage']=u;result['grossTokens']=old.charge(u)
                    assert not meta.get('error') and term.get('status')=='completed','annotation_incomplete'
                    actions=[x for x in term.get('output',[]) if x.get('type')=='function_call'];assert len(actions)==1 and actions[0]['name']=='annotate','annotation_action'
                    raw=json.loads(actions[0]['arguments'])['episodes'];result['raw']=raw
                    for item in raw:
                        try:
                            e=old.validate_episode(text,item,t,EpisodeConsumer(native),AtomicJudge(),{})
                            e['turn']=call['turn'];e['atGrossTokens']=call.get('atGrossTokens');e['repeatFact']=False;e['definiteRepeat']=False
                            if result['accepted']:assert e['span'][0]>=result['accepted'][-1]['span'][1],'overlapping_or_unsorted_quotes'
                            if e['qualifiedPositiveDerivation']:
                                prior=[p for p in accepted if p['qualifiedPositiveDerivation'] and p['atom']==e['atom']]
                                e['repeatFact']=bool(prior);e['definiteRepeat']=any(p['claimKey']==e['claimKey'] for p in prior)
                            result['accepted'].append(e);accepted.append(e)
                        except Exception as error:result['rejected'].append({'item':item,'failure':str(error)})
                except Exception as error:result['failure']=str(error)
                save(out/'receipt.json',result);print('REUSE_LABELS',row['case'],row['arm'],call['turn'],len(result['accepted']),result['failure'],flush=True)
        finally:shutdown=native.close()
        measurements.append({'case':row['case'],'arm':row['arm'],'calls':results,'shutdown':shutdown});save(run/'reuse-annotation-ledger.json',measurements)
    reuse_verify(run)

def reuse_report(run):
    plan=reuse_verify(run);rows=json.loads((run/'reuse-ledger.json').read_text());labels=json.loads((run/'reuse-annotation-ledger.json').read_text());qualification=json.loads((run/'qualification.json').read_text());points=[]
    for row in rows:
        measurement=next(x for x in labels if x['case']==row['case'] and x['arm']==row['arm'])
        for boundary in plan['checkpoints']:
            calls=[c for c in row['calls'] if c.get('atGrossTokens') is not None and c['atGrossTokens']<=boundary]
            states=[c for c in calls if 'incumbentValue' in c];last=states[-1] if states else None
            annot=[c for c in measurement['calls'] if any(s['turn']==c['turn'] for s in calls)]
            missing=sum(bool(c['failure']) for c in annot)+len(calls)-len(annot)
            episodes=[e for c in annot for e in c['accepted']]
            in_flight=any(c.get('atGrossTokens') is not None and c['atGrossTokens']-c['grossTokens']<boundary<c['atGrossTokens'] for c in row['calls'])
            reached=row['grossTokens']>=boundary and all(c['grossTokens'] is not None for c in row['calls'])
            points.append({'case':row['case'],'arm':row['arm'],'checkpoint':boundary,'reached':reached,
                'value':last['incumbentValue'] if last else qualification['tasks'][row['case']]['seed']['value'],
                'maxDepth':last['maxDepth'] if last else 0,'admittedExpansions':sum(c['evaluation']['valid'] for c in states),
                'missingAnnotations':missing,'rejectedLabels':sum(len(c['rejected']) for c in annot),
                'inFlightAtCheckpoint':in_flight,
                'observedRepeatFacts':sum(e['repeatFact'] for e in episodes) if not missing and not in_flight else None,
                'observedExactRepeatDerivations':sum(e['definiteRepeat'] for e in episodes) if not missing and not in_flight else None,
                'observedDerivations':sum(e['qualifiedPositiveDerivation'] for e in episodes),
                'observedReuse':sum(e['kind']=='reuse' for e in episodes),'solverFailure':row.get('failure')})
    joint=[{'case':case,'checkpoint':boundary,'points':[p for p in points if p['case']==case and p['checkpoint']==boundary]}
        for case in range(2) for boundary in plan['checkpoints']
        if all(next(p for p in points if p['case']==case and p['arm']==arm and p['checkpoint']==boundary)['reached'] for arm in plan['arms'])]
    known=sum(c['grossTokens'] or 0 for r in rows for c in r['calls']);unknown=sum(c['grossTokens'] is None for r in rows for c in r['calls'])
    measurement_cost=sum(c['grossTokens'] or 0 for r in labels for c in r['calls'])
    report={'planSha256':digest(run/'plan.json'),'solverKnownTokens':known,'solverUnknownCostCalls':unknown,'annotationKnownTokens':measurement_cost,
        'budgetPerTrajectory':plan['budget'],'jointlyReachedCheckpoints':joint,'trajectories':rows,'annotationResults':labels,
        'limits':'Two unchanged fixed tasks, one stochastic trajectory per arm/task. Scheme combines proof fragments and finite-absence partition; this does not isolate their individual effects. All arms replay their own prior thinking and paired tool outputs, charging all repeated input. Repeat metrics are observed, exact-quote supported lower bounds; extraction completeness and inter-rater agreement are unvalidated. At checkpoints inside a model call, repeat counts are unknown because per-token usage timing is unavailable. Unknown or rejected labels remain explicit. No hidden model reasoning is inferred. Current captured native and full gxi qualification passes; prior dyld cleanup failures remain retained and no global runtime fix is claimed. Unused budget is censored, not savings.'}
    save(run/'reuse-report.json',report)
    lines=['# Library Fact and proof-fragment reuse pilot','',report['limits'],'',
        '| Task | Arm | Input + all output | Depth | Best value / optimum | Stop |','|---|---|---:|---:|---:|---|']
    for row in rows:
        best=qualification['tasks'][row['case']]['optimum']['evaluation']['value']
        lines.append(f"| {row['case']} | {row['arm']} | {row['grossTokens']} | {row['maxDepth']} | {row['incumbent']['evaluation']['value']} / {best} | {row['stop']} {row.get('failure','')} |")
    lines += ['',f'Solver known cost: {known} tokens; unknown-cost calls: {unknown}. Independent annotation cost: {measurement_cost} tokens, recorded separately.',
        '','## Jointly reached input + all-output checkpoints','','| Task / budget | Arm | Value | Depth | Observed repeated Facts / exact derivations | Missing / rejected labels |','|---|---|---:|---:|---:|---:|']
    for group in joint:
        for p in group['points']:lines.append(f"| {p['case']} / {p['checkpoint']} | {p['arm']} | {p['value']} | {p['maxDepth']} | {p['observedRepeatFacts']} / {p['observedExactRepeatDerivations']} | {p['missingAnnotations']} / {p['rejectedLabels']} |")
    lines += ['','A checkpoint excludes a model action that completes after the boundary. Unreached checkpoints are excluded from matched comparisons. Full outcomes, invalid branches, provider failures, forced cleanup, raw thinking, anchored labels and rejected annotations are retained. The unchanged ordinary search question contains no anti-repetition instructions.']
    (run/'reuse-report.md').write_text('\n'.join(lines)+'\n')
    snippets=[]
    for phase in labels:
        for call in phase['calls']:
            for e in call['accepted']:
                snippets += [f"- task {phase['case']}, arm {phase['arm']}, call {call['turn']}, span {e['span']}, atom {e['atom']}, kind {e['kind']}, repeated Fact {e['repeatFact']}, exact repeated derivation {e['definiteRepeat']}", '', '> '+e['quote'].replace('\n','\n> '), '']
    (run/'thinking-episodes.md').write_text('\n'.join(snippets)+'\n')
    doc=ROOT/'.cache/ascent/research-reports/agent-inference/fact-reuse-results'/run.name;doc.mkdir(parents=True,exist_ok=False)
    for src,dst in [('reuse-report.json','report.json'),('reuse-report.md','report.md'),('plan.json','plan.json'),('qualification.json','qualification.json'),('reuse-ledger.json','ledger.json'),('reuse-annotation-ledger.json','annotation-ledger.json'),('thinking-episodes.md','thinking-episodes.md')]:shutil_copy(run/src,doc/dst)
    with tarfile.open(doc/'raw.tar.gz','w:gz') as tar:
        tar.add(run,arcname='run');tar.add(RUNTIME,arcname='runtime');tar.add(CANONICAL.parent,arcname='canonical-runtime')
        base=RUNTIME.parent
        for p in sorted(base.glob('shutdown-*')):tar.add(p,arcname='shutdown/'+p.name)
        for p in sorted(base.glob('reuse*.json')):tar.add(p,arcname='receipts/'+p.name)
        for p in sorted(base.glob('reuse*.log')):tar.add(p,arcname='logs/'+p.name)
    save(doc/'integrity.json',{'bindingVerified':True,'files':{p.name:digest(p) for p in doc.iterdir() if p.is_file() and p.name!='integrity.json'}})
    print('REUSE_REPORT_COMPLETE',known,measurement_cost,flush=True)

def shutil_copy(source,dest):
    dest.write_bytes(source.read_bytes())

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['freeze','solve','reuse-freeze','reuse-solve','reuse-annotate','reuse-report']);parser.add_argument('--run-dir',type=Path,required=True)
    a=parser.parse_args();globals()[a.command.replace('-', '_')](a.run_dir.resolve())
