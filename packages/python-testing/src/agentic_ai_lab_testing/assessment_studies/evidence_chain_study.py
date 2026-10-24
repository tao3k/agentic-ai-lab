# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Independent three-arm study isolating retained component reuse from execution."""
import argparse,concurrent.futures,contextlib,copy,hashlib,json,multiprocessing,os,shutil,time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain,normalize_contract
from . import evidence_chain_workload as workload
from . import inference_reuse_study as s
from .inference_effort import until_verified,paired_reduction
from .model_study import provider,response_outcome
from .movie_study import provider_key

ARMS=('raw-fact-reasoning','scheme-fresh-execution','scheme-retained-chain')
_ENGINE=None


def loose_json(text):
    """One JSON payload may be surrounded by prose or a Markdown fence."""
    if isinstance(text,(dict,list)):return copy.deepcopy(text)
    try:return json.loads(text)
    except (ValueError,TypeError):pass
    decoder=json.JSONDecoder();values=[];position=0
    while position<len(text):
        if text[position] not in '{[':position+=1;continue
        try:value,size=decoder.raw_decode(text[position:]);values.append(value);position+=size
        except ValueError:position+=1
    if len(values)!=1:raise ValueError('Provide one unambiguous JSON payload; surrounding prose is allowed.')
    return values[0]


def tools(assisted):
    definitions=[{'type':'function','name':'scan_facts','description':'Read named finite source relations; omit relations to read all. Actor indices refer to the ordered Actor domain returned here.',
                  'parameters':{'type':'object','properties':{'relations':{'type':'array','items':{'type':'string'}}}}},
                 {'type':'function','name':'submit_answer','description':'Submit actor identifiers or zero-based Actor indices, OR reference a previously checked unary result using reference and relation. Verification returns verified/not_verified. Sources are checked for identifier membership before grading.',
                  'parameters':{'type':'object','properties':{'answer':{'type':'array'},'reference':{'type':'string'},'relation':{'type':'string'}}}}]
    if assisted:definitions.append({'type':'function','name':'check_evidence',
        'description':'Execute expressed relational claims in Scheme. contract has relations (name/types) and rules (head/body atoms with relation/terms). Terms are var or const objects; body atoms may have not:true. A single head object or head array is accepted. Declare only new derived relations; answer already exists. queries selects relation names. Completed components may be reused according to returned retention metadata; re-express a previous definition or extend a retained claim. A check certifies rule consequences, not English intent.',
        'parameters':{'type':'object','properties':{'contract':{'type':'object'},'queries':{'type':'array','items':{'type':'string'}}}}})
    return definitions


def prepare(library,directory):
    directory.mkdir(parents=True,exist_ok=False);shutil.copy2(library,directory/library.name)
    paths=[Path(__file__),Path(workload.__file__),Path(s.__file__),
           Path(__file__).with_name('model_study.py'),Path(__file__).with_name('inference_effort.py'),Path(__file__).with_name('movie_study.py'),
           s.ROOT/'rust/ascent-python/src/api/exports.rs',s.ROOT/'rust/ascent/src/derivations.rs',
           s.ROOT/'rust/ascent-python/src/api/evidence.rs',s.ROOT/'rust/ascent/src/conversation.rs']
    plan={'schema':'ascent.evidence-chain-study.v1','corpusKind':'synthetic-mechanism-regression','arms':list(ARMS),'repetitions':2,'maxTurns':8,'maxOutputTokens':131072,'workers':2,
          'library':library.name,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),
          'cases':[workload.workload(i,20271011+i*1009) for i in range(4)],
          'producerHashes':{str(p.relative_to(s.ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
          'primary':'Cumulative thinking through first independently verified correct answer; all failures and repairs charged, censoring retained.',
          'ablation':'Fresh and retained Scheme arms have identical tools, instructions, result references and provider reasoning history; only component persistence differs.',
          'holdout':'New compound structures, 120 entities, new random chords and seeds; no original question/source reused. Frozen before paid calls.',
          'outputPolicy':'Automatic tool choice, no response-format schema, no required tool choice, prose-wrapped JSON accepted, equivalent singleton head normalized locally; Scheme authority/type/stratification validation preserved.',
          'recovery':'Output exhaustion stays charged and full incomplete reasoning is forwarded within the eight-turn bound. No gold feedback.',
          'costBoundary':'Result references available identically in both Scheme arms; this optimization cannot be credited to retained component reuse.'}
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')


def grade_answer(args,chain,case,observed):
    if not observed:raise ValueError('Acquire source facts or checked evidence before submitting an answer.')
    if 'reference' in args:
        values=[r[0] for r in chain.answer(args['reference'],args.get('relation','answer'))]
    else:
        values=args['answer']
        if not isinstance(values,list):raise ValueError('answer must be a list or a checked result reference')
        domain=case['source']['domains']['Actor']
        values=[domain[x] if type(x)==int and 0<=x<len(domain) else x for x in values]
        if any(not isinstance(x,str) or x not in domain for x in values):raise ValueError('Answer contains identifiers outside the supplied Actor domain; original identifiers or zero-based domain indices are accepted.')
    return sorted(set(values))==[r[0] for r in workload.expected(case,case['source'])]


def episode(plan,plan_dir,output,case,rep,arm):
    global _ENGINE
    directory=output/f"{case['name']}-rep-{rep}-{arm}";directory.mkdir();(directory/'paid-claim.json').open('x').close()
    with (directory/'progress.txt').open('w') as log,contextlib.redirect_stdout(log):
        if _ENGINE is None:_ENGINE=ReasoningRuntime(plan_dir/plan['library'])
        assisted=arm!=ARMS[0];base=s.program(case['source'],{'relations':[],'rules':[]})
        record={'case':case['name'],'repetition':rep,'arm':arm,'attempts':[],'evidenceJournal':[]}
        def save():(directory/'episode.json').write_text(json.dumps(record,indent=2)+'\n')
        history=ResponseHistory(json.dumps({'question':case['question'],'schema':s.SCHEMA},sort_keys=True));origins={};observed=False
        instructions=('Solve the complete complex question using only supplied finite relations. Reason naturally; no subproblem-first plan is required. '
                      'cast maps Film to Actor; directed Film to Director; citizen Director to Country; mentor is directed Actor to Actor. '
                      'Positive recursion uses a least fixed point; negation must be stratified and positively bound. Source heads are forbidden. '
                      'Function calls are available but not forced. Prose and fenced JSON are accepted for a final answer. '
                      'An answer can use original actor IDs or zero-based Actor indices, so copying opaque strings is unnecessary. '
                      'For Scheme tools, a checked unary relation can be submitted by result reference; this does not certify English intent. '
                      'Use existing checked components when the retention metadata permits; avoid reconstructing a completed recursive closure. '
                      'Do not redeclare source relations or the already declared answer(Actor). A single head atom or head array is accepted. '
                      'If needed, extend expressed claims in a later check. Verification reveals no correct values. '
                      +('Scheme execution is available.' if assisted else 'Reason over scanned raw facts; Scheme execution is unavailable.'))
        started=time.monotonic()
        with EvidenceChain(_ENGINE,[r for r in base['relations'] if r['source']],arm==ARMS[2]) as chain:
            record['setupSeconds']=time.monotonic()-started;save();key=provider_key()
            for turn in range(1,plan['maxTurns']+1):
                request={'model':'deepseek-flash','input':history.input(),'instructions':instructions,'tools':tools(assisted),
                         'tool_choice':'auto','reasoning':{'effort':'high'},'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}
                (directory/f'{turn}.request.json').write_text(json.dumps(request,indent=2)+'\n')
                raw,meta=provider(request,key,directory/f'{turn}.response.json');(directory/f'{turn}.raw.txt').write_text(raw)
                terminal=meta.get('terminal')or{};outcome=response_outcome(meta)
                a={'turn':turn,'providerCalls':1,'usage':terminal.get('usage'),'correct':False,'providerOutcome':outcome,
                   'providerSeconds':meta['providerSeconds'],'priorReasoningItems':history.reasoning_items,'toolActions':[],
                   'requestSha256':s.identity(request),'sourceIdentity':chain.source_identity}
                record['attempts'].append(a);save()
                if meta.get('error') or not a['usage']:a['outcome']='provider_failure';save();raise RuntimeError('Transport failed; stop dispatch, retain partial receipt.')
                calls=history.append_response(terminal);started=time.monotonic()
                if not calls:
                    try:
                        value=loose_json(raw);args=value if isinstance(value,dict) else {'answer':value}
                        a['correct']=grade_answer(args,chain,case,observed);a['action']={'action':'answer',**args}
                        feedback={'verification':'verified' if a['correct'] else 'not_verified'}
                        a['outcome']='verified_answer' if a['correct'] else 'answer_not_verified'
                    except Exception as error:
                        feedback={'error':str(error)[:2048],'guidance':'You may use submit_answer, actor indices, or one prose-wrapped JSON answer payload.'}
                        a['outcome']='output_budget_exhausted' if outcome=='output_budget_exhausted' else 'action_failure'
                    a['feedback']=feedback;history.append_feedback(feedback)
                for call in calls:
                    action={'name':call['name'],'callId':call['call_id'],'correct':False};a['toolActions'].append(action)
                    try:
                        if call.get('status')=='incomplete':raise ValueError('Incomplete function call was not executed; continue with a complete call.')
                        args=loose_json(call['arguments'])
                        if call['name']=='scan_facts':
                            names=args.get('relations',list(s.SCHEMA));feedback=chain.scan(names);feedback['actorIndices']=case['source']['domains']['Actor'];observed=True;kind='scan'
                        elif call['name']=='check_evidence' and assisted:
                            contract=normalize_contract(args['contract']);program=s.program(case['source'],contract);program['queries']=args.get('queries',['answer'])
                            feedback=chain.query(program);observed=True;kind='query'
                            for component in feedback['freshComponents']:origins.setdefault(component['fingerprint'],turn)
                            feedback['crossRoundReusedComponents']=[c for c in feedback['reusedComponents'] if origins.get(c['fingerprint'],turn)<turn]
                            record['evidenceJournal'].append(feedback)
                        elif call['name']=='submit_answer':
                            kind='answer';action['correct']=grade_answer(args,chain,case,observed);a['correct']|=action['correct']
                            feedback={'verification':'verified' if action['correct'] else 'not_verified'}
                        else:raise ValueError('Tool unavailable in this condition.')
                        action.update(action={'action':kind,**args},outcome='verified_answer' if action['correct'] else 'answer_not_verified' if kind=='answer' else 'evidence_progress')
                    except Exception as error:
                        feedback={'error':str(error)[:2048]};action['outcome']='action_failure'
                    action['feedback']=feedback;history.append_result(call['call_id'],feedback)
                if calls:a['outcome']='verified_answer' if a['correct'] else 'output_budget_exhausted' if outcome=='output_budget_exhausted' else 'action_failure' if any(t['outcome']=='action_failure' for t in a['toolActions']) else 'answer_not_verified' if any(t['outcome']=='answer_not_verified' for t in a['toolActions']) else 'evidence_progress'
                a['schemeSeconds']=time.monotonic()-started;record['effort']=until_verified(record['attempts']);save()
                print('CHAIN-ROUND',case['name'],rep,arm,turn,a['outcome'],flush=True)
                if a['correct']:break
            record['effort']=until_verified(record['attempts']);save()
    return record


def live(plan_dir,output):
    pp=plan_dir/'plan.json';plan=json.loads(pp.read_text())
    if plan.get('corpusKind')!='admitted-external-source':
        raise ValueError('Paid primary evaluation requires admitted external-source tasks; synthetic cases are offline mechanism regressions.')
    for rel,sha in plan['producerHashes'].items():
        if hashlib.sha256((s.ROOT/rel).read_bytes()).hexdigest()!=sha:raise ValueError('producer drift')
    if hashlib.sha256((plan_dir/plan['library']).read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('library drift')
    output.mkdir(parents=True,exist_ok=False);(plan_dir/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.evidence-chain-result.v1','planSha256':hashlib.sha256(pp.read_bytes()).hexdigest(),'providerCalls':0,'peakEstimateUsd':0,'episodes':[]}
    def save():(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def add(e):
        receipt['episodes'].append(e);receipt['providerCalls']+=len(e['attempts']);receipt['peakEstimateUsd']+=sum(s.price(a['usage']) for a in e['attempts']);save()
    save();jobs=[]
    for i,case in enumerate(plan['cases']):
        for rep in range(plan['repetitions']):
            order=list(ARMS);offset=(i+rep)%3;order=order[offset:]+order[:offset]
            jobs.extend((case,rep,arm) for arm in order)
    # One real trajectory qualifies transport before any concurrent fan-out.
    add(episode(plan,plan_dir,output,*jobs.pop(0)))
    with concurrent.futures.ProcessPoolExecutor(max_workers=2,mp_context=multiprocessing.get_context('spawn')) as pool:
        iterator=iter(jobs);pending={pool.submit(episode,plan,plan_dir,output,*next(iterator)) for _ in range(2)}
        while pending:
            done,pending=concurrent.futures.wait(pending,return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                try:add(future.result())
                except Exception:
                    for other in pending:other.cancel()
                    raise
                job=next(iterator,None)
                if job:pending.add(pool.submit(episode,plan,plan_dir,output,*job))
    receipt['complete']=True;save();print('EVIDENCE-CHAIN-COMPLETE',receipt['providerCalls'],flush=True)


# Minimal shared-premise diagnostic in the existing Python project consumer.
SHARED_CANDIDATE = ['candidate', ['relation', 'path', 2], ['relation', 'ready', 1],
    ['rule', ['path', '?x', '?y'], ['edge', '?x', '?y']],
    ['rule', ['path', '?x', '?z'], ['path', '?x', '?y'], ['edge', '?y', '?z']],
    ['rule', ['ready', '?f'], ['need', '?f', '?a', '?b', '?c', '?d'],
        ['path', '?a', '?b'], ['path', '?c', '?d']],
    ['query', 'ready', '?f'], ['limits', 256, 1024, 1024]]
SHARED_QUESTION = 'Which of the listed transitions are permitted by the rules? Return their IDs.'
SHARED_TOOL = {'type': 'function', 'name': 'submit_answer',
    'description': 'Return the permitted transition IDs.', 'parameters': {'type': 'object',
    'properties': {'permitted': {'type': 'array', 'items': {'type': 'integer'}}},
    'required': ['permitted'], 'additionalProperties': False}}
SHARED_RUBRIC = '''Label only explicit atomic episodes in supplied visible reasoning. Each label has a verbatim contiguous quote, zero-based occurrence, category, concluded atom and explicitly stated ordered premises. Categories: premise_consumed (uses established evidence without proving it again), positive_derivation (an actual supported inference), absence_recheck (explicit argument that a path or transition is absent), new_residual (a supported inference about the current downstream obligation), arithmetic (resource/objective computation), ambiguous (unsupported or unclear). Relations: edge, path, ready. ready ID requires both paths of that needs row. Atom and premise endpoints must appear literally in the quote. No edges or premises may be supplied from your own source knowledge. A reference/assertion alone is not a derivation. For arithmetic and ambiguous, atom and premises may be empty. Do not infer unexposed reasoning. Do not add labels merely to populate a category. Do not repair wrong IDs. Include explicit negative reasoning, but do not infer absence from missing text. You are not given arm, score or cost; supplied reasoning can still reveal its condition. Return labels in text order. Completeness is not guaranteed.'''
SHARED_LABEL_TOOL = {'type': 'function', 'name': 'annotate', 'description': 'Record literal reasoning episodes.',
    'parameters': {'type': 'object', 'properties': {'episodes': {'type': 'array', 'items': {
    'type': 'object', 'properties': {'quote': {'type': 'string'}, 'occurrence': {'type': 'integer'},
    'category': {'type': 'string', 'enum': ['premise_consumed', 'absent_premise_consumed', 'positive_derivation', 'absence_recheck', 'new_residual', 'arithmetic', 'ambiguous']},
    'atom': {'type': 'array', 'items': {'type': ['string', 'integer']}},
    'premises': {'type': 'array', 'items': {'type': 'array', 'items': {'type': ['string', 'integer']}}}},
    'required': ['quote', 'occurrence', 'category', 'atom', 'premises'], 'additionalProperties': False}}},
    'required': ['episodes'], 'additionalProperties': False}}


def shared_tasks():
    edges = [[0,1],[1,2],[0,10],[10,2],[3,4],[5,6],[7,8],[8,9],[11,12]]
    needs = [[0,0,2,3,4],[1,0,2,4,3],[2,0,2,5,6],[3,0,2,6,5],[4,0,2,7,9],[5,0,2,9,7]]
    return [{'id': f'shared-premise-{i}', 'edges': edges if i == 0 else
              [e for e in edges if e != [5,6]] + [[6,5]], 'needs': needs,
              'schedule': [[0,1],[2,3],[4,5]], 'sharedAtom': ['path',0,2]} for i in range(2)]


def shared_source(task, generation=0, edges=None):
    return {'identity': task['id'], 'generation': generation,
            'relations': [['edge',2,task['edges'] if edges is None else edges], ['need',5,task['needs']]]}


def shared_truth(task, atom):
    """Independent finite graph oracle for this fixture, never production evaluation."""
    if not isinstance(atom,list) or not atom or atom[0] not in ('edge','path','ready'):
        raise ValueError('unknown fixture atom')
    if any(type(n) is not int for n in atom[1:]): raise ValueError('noninteger atom')
    if atom[0] == 'edge':
        if len(atom) != 3: raise ValueError('edge arity')
        return atom[1:] in task['edges']
    if atom[0] == 'ready':
        if len(atom) != 2: raise ValueError('ready arity')
        n = next(n for n in task['needs'] if n[0] == atom[1])
        return shared_truth(task,['path',n[1],n[2]]) and shared_truth(task,['path',n[3],n[4]])
    if len(atom) != 3: raise ValueError('path arity')
    todo = [b for a,b in task['edges'] if a == atom[1]]; seen = set()
    while todo:
        at = todo.pop()
        if at == atom[2]: return True
        if at in seen: continue
        seen.add(at); todo.extend(b for a,b in task['edges'] if a == at)
    return False


def shared_atoms(task, ids):
    return [list(a) for a in dict.fromkeys(tuple(a) for n in task['needs'] if n[0] in ids
        for a in (['path',n[1],n[2]], ['path',n[3],n[4]]))]


def shared_packet(store, task, ids):
    src=shared_source(task); begin=time.monotonic(); r=store.resolve(src,SHARED_CANDIDATE)
    if r['status'] != 'verified': raise ValueError('unverified native evidence')
    facts=[]; fragments=[]
    for atom in shared_atoms(task,ids):
        f=store.fact(src,SHARED_CANDIDATE,r['handle'],atom)
        if f['status'] not in ('verified','finite-absent'): raise ValueError('unknown native fact')
        if (f['status']=='verified') != shared_truth(task,atom): raise ValueError('native/oracle disagreement')
        facts.append({'atom':atom,'status':f['status']})
        if f['status']=='verified':
            p=store.fragment(src,SHARED_CANDIDATE,r['handle'],atom)
            if p['status']!='verified': raise ValueError('unverified fragment')
            fragments.append({'atom':atom,'roots':p['roots'],'nodes':p['nodes']})
    return {'scope':dict(r['scope']),'facts':facts,'fragments':fragments,
            'nodeEncoding':['id','kind','relation','row','ruleLabel','inputs'],
            'nativeStats':store.stats(),'nativeSeconds':time.monotonic()-begin,'reused':r['reused']}


def shared_qualify(engine):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    results=[]
    for task in shared_tasks():
        with ComputationalEvidence(engine) as store:
            src=shared_source(task); first=store.resolve(src,SHARED_CANDIDATE)
            assert first['status']=='verified'
            assert sorted(first['rows'])==[[n[0]] for n in task['needs'] if shared_truth(task,['ready',n[0]])]
            packets=[shared_packet(store,task,ids) for ids in task['schedule']]
            assert all(p['nativeStats']['proof-builds']==1 and p['reused'] for p in packets)
            shared=[next(f for f in p['fragments'] if f['atom']==task['sharedAtom']) for p in packets]
            assert shared[0]==shared[1]==shared[2]
            for p in packets:
                for f in p['fragments']:
                    ids=set();assert all(not any(parent not in ids for parent in n[5]) and
                        not (n[0] in ids) and (ids.add(n[0]) is None) for n in f['nodes'])
                    assert set(f['roots']) <= ids
            handle=first['handle']; remaining=[e for e in task['edges'] if e != [1,2]]
            alt=shared_source(task,1,remaining)
            assert store.fact(alt,SHARED_CANDIDATE,handle,task['sharedAtom'])['status']=='unknown'
            ar=store.resolve(alt,SHARED_CANDIDATE);assert ar['status']=='verified'
            assert store.fact(alt,SHARED_CANDIDATE,ar['handle'],task['sharedAtom'])['status']=='verified'
            removed=shared_source(task,2,[e for e in remaining if e != [10,2]])
            assert store.fragment(removed,SHARED_CANDIDATE,ar['handle'],task['sharedAtom'])['status']=='unknown'
            rr=store.resolve(removed,SHARED_CANDIDATE);assert rr['status']=='verified' and rr['rows']==[]
            assert store.fact(removed,SHARED_CANDIDATE,rr['handle'],task['sharedAtom'])['status']=='finite-absent'
            mutants=[]
            for kind in ('missing-rule','wrong-join'):
                mutant=copy.deepcopy(SHARED_CANDIDATE)
                if kind=='missing-rule':mutant.pop(4)
                else:mutant[4][-1]=['edge','?x','?z']
                bad=store.resolve(src,mutant);assert bad['status']=='verified'
                # Grade intermediate shared P too: final ready rows alone miss this wrong join.
                assert store.fact(src,mutant,bad['handle'],['path',0,2])['status']=='finite-absent'
                assert shared_truth(task,['path',0,2])
                assert store.fact(src,mutant,handle,['path',0,2])['status']=='unknown'
                mutants.append(kind)
            results.append({'task':task['id'],'packets':packets,'alternativeSupportPreserved':True,
                'staleHandlesRefused':True,'withdrawalRecomputed':True,'mutantsDistinguished':mutants})
    import subprocess
    model=s.ROOT/'packages/proofs/quint/SharedPremiseReuse.qnt'
    raw=subprocess.check_output(['quint','repl','-q','--backend','typescript','-r',str(model)+'::SharedPremiseReuse','conformance'],text=True,timeout=30)
    expected=json.loads(raw);observed=[]
    with ComputationalEvidence(engine) as store:
        for i in range(32):
            edges=[e for bit,e in zip([1,2,4,8,16],[[0,1],[1,2],[0,10],[10,2],[3,4]]) if i & bit]
            task={'id':f'quint-conformance-{i}','edges':edges,'needs':[[0,0,2,3,4]]}
            src=shared_source(task);r=store.resolve(src,SHARED_CANDIDATE);assert r['status']=='verified'
            p=store.fact(src,SHARED_CANDIDATE,r['handle'],['path',0,2])
            observed.append([i,int(p['status']=='verified'),int([0] in r['rows'])])
    assert observed==expected,'Scheme/Quint finite observation mismatch'
    return {'taskChecks':results,'nativeQuintRows':observed,'quintCommand':['quint','repl','-q','--backend','typescript','-r','packages/proofs/quint/SharedPremiseReuse.qnt::SharedPremiseReuse','conformance']}


def shared_freeze(library, directory, *, search_tasks=None):
    directory.mkdir(parents=True,exist_ok=False)
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    import agentic_ai_lab_runtime.reasoning as evidence_module
    from importlib.util import find_spec
    from .interface_tests import qualification_inputs, compiled_inputs
    root=s.ROOT.resolve()
    library=Path(find_spec('agentic_ai_lab_runtime._reasoning').origin).resolve()
    dst=directory/library.name;shutil.copy2(library,dst)
    # Use the installed API extension when available, rather than falling back silently.
    with ReasoningRuntime() as engine:
        qualification=shared_qualify(engine)
        if search_tasks is not None:qualification['branchTaskChecks']=branch_qualify(engine,search_tasks)
    (directory/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n')
    native_receipt=compiled_inputs()
    binding=dict(native_receipt['sourceInputs'])
    # The installed application artifact carries the resolved producer's source
    # digests; qualification_inputs checks the independently installed core wheel.
    names=['gerbil.pkg','packages/python-runtime/pyproject.toml',
           'packages/python-runtime/setup.py','packages/proofs/quint/package.json',
           'packages/proofs/quint/package-lock.json','packages/proofs/lean/lean-toolchain']
    names += [str(p.relative_to(root)) for p in (root/'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies').glob('*.py')]
    names += [str(p.relative_to(root)) for p in (root/'packages/proofs/lean/AgenticAILabProof/EvidenceAssessment').glob('*.lean')]
    names += ['packages/proofs/quint/SharedPremiseReuse.qnt','packages/proofs/quint/VerifiedCandidate.qnt']
    if search_tasks is not None:names += ['t/research/reproduce-clean.sh','t/research/output-check-fixture.json']
    for name in names: binding[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
    for name,h in binding.items():
        assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,'source drift '+name
        target=directory/'inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/name,target)
    runtime_inputs=qualification_inputs([])
    (directory/'pyo3-runtime-receipt.json').write_text(json.dumps(runtime_inputs,indent=2)+'\n')
    (directory/'native-build-receipt.json').write_text(json.dumps(native_receipt,indent=2)+'\n')
    metadata={'schema':'ascent.shared-premise-diagnostic.v1','tasks':shared_tasks(),'candidate':SHARED_CANDIDATE,
        'question':SHARED_QUESTION,'tool':SHARED_TOOL,'arms':['baseline','facts','scheme'],
        'orders':[['baseline','facts','scheme'],['scheme','facts','baseline']],
        'model':'deepseek-flash','reasoningEffort':'low','totalBudget':32768,'maxOutputTokens':32768,
        'minimumOutputTokens':1024,'inputPadding':256,'maxCalls':3,'checkpoints':[4096,8192,16384,24576,32768],
        'library':library.name,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),
        'inputs':binding,'qualificationSha256':hashlib.sha256((directory/'qualification.json').read_bytes()).hexdigest(),
        'annotationRubric':SHARED_RUBRIC,'annotationTool':SHARED_LABEL_TOOL,'annotationPasses':2,'annotationOutputCap':8192,
        'annotationRules':'Exact nonoverlapping quotes; endpoint literals; independent finite truth; explicit ordered edge/path chain or ready conjunction for positive inference. premise_consumed must refer to an earlier or supplied true atom. new_residual is derived by classification after validation, never trusted from label name. A repeated positive atom is counted across different questions in the same source scope. Exact-premise repeat reported separately. Negative claims require an explicit negative argument and independently absent atom, but completeness of the quoted absence argument is unproven. Arithmetic and ambiguity are reported without assigning cached-atom savings. Rejected/empty/missing labels remain visible. Two blind passes of the SAME model are correlated annotations, not independent-rater validation.',
        'claims':{'correctReuse':'Equal native support nodes across different obligations; source/handle binding and independent answer agreement.',
                  'reducedRepetition':'Requires directly supported baseline repetitions plus validated annotation coverage; native hits alone are insufficient.',
                  'newInference':'Distinct correct downstream answers and qualified nonsupplied consequences after the first obligation. No optimization or depth claim.'},
        'controls':'Same task, sibling schedule, history policy, answer schema and input-plus-all-output cap. No pruning, ranking, optimal answer or anti-repetition instruction. Fact and Scheme supply identical atomic outcomes; Scheme adds checked ancestor-closed fragments. Unused reservations are censored, not savings. All failed calls and unknown usage retained.',
        'sourceState':(json.loads((root/'.research-source.json').read_text()) if (root/'.research-source.json').exists() else {'head':__import__('subprocess').check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'dirtySourceSnapshot':True,'cleanCheckoutReproductionVerified':False}),
        'formalToolVersions':{'quint':__import__('subprocess').check_output(['quint','--version'],text=True).strip(),'lean':__import__('subprocess').check_output(['lean','--version'],cwd=root/'packages/proofs/lean',text=True).strip()},
        'papers':[{'id':'BYODS','url':'https://kmicinski.com/assets/byods.pdf','role':'concretization/delta semantics; separate from model efficacy'},
                  {'id':'DatalogBench-v1','url':'https://arxiv.org/html/2609.37233v1','role':'held-out execution and oracle mutation tests'},
                  {'id':'MiniCache-v1','url':'https://arxiv.org/html/2607.20507v1','role':'shared computation with different request variables'}],
        'formalBoundary':'SharedPremiseReuse.qnt models finite fixture truth and source-generation admission. ProofDag.lean proves specified ordered positive-DAG soundness under premises, not FFI correctness or model behavior. VerifiedCandidate assumes independent grader validity. Native correspondence receipts are separate.'}
    (directory/'plan.json').write_text(json.dumps(metadata,indent=2)+'\n')
    (directory/'plan.sha256').write_text(hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest()+'\n')
    print('SHARED_PREMISE_FROZEN', (directory/'plan.sha256').read_text().strip(),flush=True)


def shared_check(directory, _output=None):
    plan=json.loads((directory/'plan.json').read_text())
    assert hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest()==(directory/'plan.sha256').read_text().strip()
    assert hashlib.sha256((directory/plan['library']).read_bytes()).hexdigest()==plan['librarySha256']
    assert hashlib.sha256((directory/'qualification.json').read_bytes()).hexdigest()==plan['qualificationSha256']
    for name,h in plan['inputs'].items():
        path=Path(name)
        assert not path.is_absolute() and '..' not in path.parts and '.cache' not in path.parts
        assert (directory/'inputs'/path).resolve().is_relative_to((directory/'inputs').resolve())
        assert (s.ROOT/path).resolve().is_relative_to(s.ROOT.resolve())
        assert hashlib.sha256((directory/'inputs'/path).read_bytes()).hexdigest()==h,'snapshot drift '+name
        assert hashlib.sha256((s.ROOT/path).read_bytes()).hexdigest()==h,'loaded checkout drift '+name
    from .interface_tests import qualification_inputs
    runtime=json.loads((directory/'pyo3-runtime-receipt.json').read_text())
    assert qualification_inputs([])==runtime,'loaded PyO3 runtime or syntax resources drift'
    return plan


def shared_committed_check(directory, output):
    import subprocess
    plan=shared_check(directory);blocked=[]
    for name,h in plan['inputs'].items():
        p=subprocess.run(['git','show','HEAD:'+name],cwd=s.ROOT,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
        if p.returncode or hashlib.sha256(p.stdout).hexdigest()!=h:blocked.append(name)
    output.mkdir(parents=True,exist_ok=True)
    result={'portableSnapshotInputsVerified':True,'committedInputsVerified':not blocked,'blocked':blocked,
            'networkReproductionVerified':False,'portableWheelQualified':False}
    (output/'committed-input-check.json').write_text(json.dumps(result,indent=2)+'\n')
    if blocked:raise SystemExit(2)
    return result


def shared_action(terminal):
    def unique(items):
        d={}
        for k,v in items:
            if k in d:raise ValueError('duplicate answer key')
            d[k]=v
        return d
    out=terminal.get('output',[]);calls=[x for x in out if x.get('type')=='function_call']
    if calls:
        assert len(calls)==1 and calls[0]['name']=='submit_answer','ambiguous action'
        payload=calls[0]['arguments']
    else:
        messages=[x for x in out if x.get('type')=='message'];assert len(messages)==1,'missing action'
        parts=messages[0]['content'];assert parts and all(p['type']=='output_text' for p in parts)
        payload=''.join(p['text'] for p in parts)
    answer=json.loads(payload,object_pairs_hook=unique)
    assert set(answer)=={'permitted'} and isinstance(answer['permitted'],list),'invalid answer schema'
    assert all(type(i) is int for i in answer['permitted']) and len(set(answer['permitted']))==len(answer['permitted']),'invalid IDs'
    return answer['permitted'],calls


def shared_live(directory, output):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    plan=shared_check(directory);output.mkdir(parents=True,exist_ok=False);rows=[]
    save=lambda: (output/'ledger.json').write_text(json.dumps(rows,indent=2)+'\n')
    with ReasoningRuntime() as engine:
        for case,task in enumerate(plan['tasks']):
            for arm in plan['orders'][case]:
                row={'case':case,'arm':arm,'calls':[],'grossTokens':0,'stop':None,'failure':None};rows.append(row);save()
                history=None;prior_usage=None
                with ComputationalEvidence(engine) as store:
                    try:
                        for turn,ids in enumerate(task['schedule']):
                            context={'question':plan['question'],'obligations':[n for n in task['needs'] if n[0] in ids]}
                            packet=shared_packet(store,task,ids) if arm!='baseline' else None
                            if packet:
                                context['evidence']={k:packet[k] for k in ('scope','facts')}
                                if arm=='scheme':context['evidence'].update({k:packet[k] for k in ('fragments','nodeEncoding')})
                            if history is None:
                                context['task']={'edges':task['edges'],'needColumns':['id','a','b','c','d'],
                                    'rules':plan['candidate'][3:6], 'query':['ready','?f'],
                                    'semantics':'Positive rules with conjunctive bodies; path is directed reachability over edge; ready(id) requires both paths in its need row.'}
                                history=ResponseHistory(json.dumps(context,separators=(',',':')));new_items=history.snapshot()
                            else:
                                history.append_feedback(context);new_items=[history.snapshot()[-1]]
                            req={'model':plan['model'],'input':history.input(),'tools':[plan['tool']],'tool_choice':'auto',
                                 'reasoning':{'effort':plan['reasoningEffort']},'stream':True,'store':False,
                                 'text':{'format':{'type':'json_schema','name':'permitted_transitions','schema':plan['tool']['parameters']}},
                                 'max_output_tokens':plan['maxOutputTokens']}
                            bound=(len(json.dumps(req,ensure_ascii=False).encode()) if prior_usage is None else
                                prior_usage+sum(len(json.dumps(x,ensure_ascii=False).encode()) for x in new_items)) + plan['inputPadding']
                            cap=min(plan['maxOutputTokens'],plan['totalBudget']-row['grossTokens']-bound)
                            if cap<plan['minimumOutputTokens']:row.update(stop='budget_reservation',nextInputReservation=bound);break
                            req['max_output_tokens']=cap
                            folder=output/'calls'/f'{case}-{arm}'/str(turn);folder.mkdir(parents=True)
                            record={'turn':turn,'usage':None,'grossTokens':None,'failure':None,'correct':False,'inputReservation':bound,'outputCap':cap,'nativePacket':packet}
                            row['calls'].append(record);save();(folder/'request.json').write_text(json.dumps(req,indent=2)+'\n')
                            _,meta=provider(req,provider_key(),folder/'response.json');term=meta.get('terminal') or {}
                            text=''.join(p.get('text','') for x in term.get('output',[]) if x.get('type')=='reasoning'
                                        for p in x.get('content',[]) if p.get('type')=='reasoning_text')
                            (folder/'thinking.txt').write_text(text);record['thinkingSha256']=hashlib.sha256(text.encode()).hexdigest()
                            record.update(status=term.get('status'),providerError=meta.get('error'),incompleteDetails=term.get('incomplete_details'),usage=term.get('usage'))
                            u=record['usage']
                            if not isinstance(u,dict) or any(type(u.get(k)) is not int or u[k]<0 for k in ('input_tokens','output_tokens')):raise ValueError('unknown usage')
                            record['grossTokens']=u['input_tokens']+u['output_tokens'];row['grossTokens']+=record['grossTokens'];record['atGrossTokens']=row['grossTokens']
                            assert u['input_tokens']<=bound and u['output_tokens']<=cap and row['grossTokens']<=plan['totalBudget'],'budget violation'
                            if meta.get('error') or term.get('status')!='completed':raise ValueError('provider incomplete or failed')
                            answer,calls=shared_action(term);assert set(answer)<=set(ids),'unknown transition ID'
                            record.update(answer=answer,expected=[i for i in ids if shared_truth(task,['ready',i])])
                            record['correct']=sorted(answer)==record['expected'];history.append_response(term)
                            for call in calls:history.append_result(call['call_id'],{'recorded':True})
                            prior_usage=record['grossTokens']
                            # A paired result is extra input too, not part of the previous usage.
                            if calls:prior_usage+=sum(len(json.dumps(x,ensure_ascii=False).encode()) for x in history.snapshot()[-len(calls):])
                            (folder/'receipt.json').write_text(json.dumps(record,indent=2)+'\n');save()
                            print('SHARED_TURN',case,arm,turn,row['grossTokens'],'correct',record['correct'],flush=True)
                        row['stop']=row['stop'] or 'schedule_complete'
                    except Exception as error:
                        row.update(stop='failure',failure=str(error))
                        if row['calls']:
                            row['calls'][-1]['failure']=str(error)
                            (output/'calls'/f'{case}-{arm}'/str(row['calls'][-1]['turn'])/'receipt.json').write_text(json.dumps(row['calls'][-1],indent=2)+'\n')
                    finally:
                        row['unusedBudget']=plan['totalBudget']-row['grossTokens'] if all(c['grossTokens'] is not None for c in row['calls']) else None;save()
    shared_check(directory);print('SHARED_MODEL_COMPLETE',flush=True)


def shared_validate_label(text,item,task,supplied,prior,*,supplied_absent=()):
    import re
    required={'quote','occurrence','category','atom','premises'}
    assert isinstance(item,dict) and set(item)==required,'label schema'
    quote=item['quote'];occurrence=item['occurrence'];category=item['category']
    assert isinstance(quote,str) and quote and type(occurrence) is int and occurrence>=0
    assert category in SHARED_LABEL_TOOL['parameters']['properties']['episodes']['items']['properties']['category']['enum']
    at=-1
    for _ in range(occurrence+1):
        at=text.find(quote,at+1);assert at>=0,'quote not verbatim'
    result={**item,'span':[at,at+len(quote)],'qualifiedPositive':False,'repeatFact':False,'exactRepeat':False,'newConsequence':False}
    if category in ('arithmetic','ambiguous'):
        assert item['atom']==[] and item['premises']==[],'nonsemantic category must not assign atoms'
        return result
    atom=item['atom'];premises=item['premises'];truth=shared_truth(task,atom)
    numbers={int(x) for x in re.findall(r'(?<![\w.])-?\d+(?![\w.])',quote)}
    assert all(n in numbers for a in [atom,*premises] for n in a[1:]),'endpoints absent from quote'
    if category=='absent_premise_consumed':
        assert not truth and atom in supplied_absent,'negative premise not previously supplied as finite-absent'
        assert not premises and re.search(r'\b(native|evidence|given|conclusion)\b',quote,re.I),'negative use must explicitly reference supplied evidence, not invent a proof'
        result['negativePremiseConsumed']=True
        return result
    if category=='absence_recheck':
        assert not truth and re.search(r'\b(no|not|cannot|unreachable|absent|missing|false)\b',quote,re.I),'unsupported absence label'
        result['absenceArgumentCompletenessVerified']=False
        return result
    assert truth,'false positive conclusion'
    if category=='premise_consumed':
        assert atom in supplied or any(p['atom']==atom and p['qualifiedPositive'] for p in prior),'premise not established'
        return result
    assert premises and atom not in premises,'empty or circular support'
    assert all(shared_truth(task,p) for p in premises),'false stated premise'
    if atom[0]=='path':
        assert len(premises)>1 or premises[0][0]=='edge','reference alone is not derivation'
        cursor=atom[1]
        for p in premises:
            assert p[0] in ('edge','path') and p[1]==cursor,'nonchain support'
            cursor=p[2]
        assert cursor==atom[2],'wrong chain endpoint'
    elif atom[0]=='ready':
        n=next(n for n in task['needs'] if n[0]==atom[1])
        assert premises==[['path',n[1],n[2]],['path',n[3],n[4]]],'wrong conjunction support'
    else:raise ValueError('source assertion is not a derived consequence')
    previous=[p for p in prior if p['qualifiedPositive'] and p['atom']==atom]
    result.update(qualifiedPositive=True,repeatFact=bool(previous),exactRepeat=any(p['premises']==premises for p in previous),
                  newConsequence=not previous and atom not in supplied,
                  suppliedPremiseRederived=atom in supplied)
    return result


def shared_label(directory, output):
    if shared_check(directory).get('annotationMode')=='literal-partition':return branch_label(directory,output)
    plan=shared_check(directory);rows=json.loads((output/'ledger.json').read_text());all_labels=[]
    dest=output/'annotations';dest.mkdir(exist_ok=False)
    for row in rows:
        task=plan['tasks'][row['case']]
        for pass_id in range(plan['annotationPasses']):
            prior=[];result={'case':row['case'],'arm':row['arm'],'pass':pass_id,'calls':[]};all_labels.append(result)
            for call in row['calls']:
                folder=output/'calls'/f"{row['case']}-{row['arm']}"/(f"{call['turn']}-{call['step']}" if plan.get('experiment')=='sibling-search' else str(call['turn']));source=folder/'thinking.txt'
                blind=hashlib.sha256((task['id']+str(pass_id)+str(call['turn'])+str(call.get('step',0))).encode()).hexdigest()[:18]
                out=dest/blind/f"{row['arm']}";out.mkdir(parents=True)
                record={'turn':call['turn'],'step':call.get('step',0),'modelCalled':False,'grossTokens':None,'failure':None,'accepted':[],'rejected':[]};result['calls'].append(record)
                try:
                    text=source.read_text();assert hashlib.sha256(text.encode()).hexdigest()==call['thinkingSha256']
                    assert text,'no visible reasoning'
                    req={'model':plan['model'],'input':[{'role':'user','content':json.dumps({'edges':task['edges'],'needs':task['needs'],'reasoningText':text})}],
                         'instructions':plan['annotationRubric'],'tools':[plan['annotationTool']],'tool_choice':{'type':'function','name':'annotate'},
                         'reasoning':{'effort':'none'},'max_output_tokens':plan['annotationOutputCap'],'stream':True,'store':False}
                    (out/'request.json').write_text(json.dumps(req,indent=2)+'\n')
                    record['modelCalled']=True
                    _,meta=provider(req,provider_key(),out/'response.json');term=meta.get('terminal') or {};u=term.get('usage')
                    if isinstance(u,dict) and all(type(u.get(k)) is int and u[k]>=0 for k in ('input_tokens','output_tokens')):
                        record['grossTokens']=u['input_tokens']+u['output_tokens']
                    assert not meta.get('error') and term.get('status')=='completed','annotation provider failure'
                    calls=[c for c in term['output'] if c['type']=='function_call'];assert len(calls)==1 and calls[0]['name']=='annotate'
                    raw=json.loads(calls[0]['arguments']);assert set(raw)=={'episodes'} and isinstance(raw['episodes'],list)
                    record['raw']=raw['episodes'];supplied=call['suppliedAtoms'] if plan.get('experiment')=='sibling-search' else [f['atom'] for f in (call.get('nativePacket') or {}).get('facts',[]) if f['status']=='verified']
                    for item in raw['episodes']:
                        try:
                            label=shared_validate_label(text,item,task,supplied,prior)
                            assert not record['accepted'] or label['span'][0]>=record['accepted'][-1]['span'][1],'overlapping labels'
                            label.update(turn=call['turn'],step=call.get('step',0),afterFirstQuestion=call['turn']>0)
                            old=[p for p in prior if p['qualifiedPositive'] and p['atom']==label['atom']]
                            label.update(crossBranchRepeat=any(p['turn']!=call['turn'] for p in old),
                                         sameBranchRepeat=any(p['turn']==call['turn'] and p.get('step',0)!=call.get('step',0) for p in old),
                                         withinResponseRepeat=any(p['turn']==call['turn'] and p.get('step',0)==call.get('step',0) for p in old))
                            record['accepted'].append(label);prior.append(label)
                        except Exception as error:record['rejected'].append({'item':item,'failure':str(error)})
                except Exception as error:record['failure']=str(error)
                (out/'receipt.json').write_text(json.dumps(record,indent=2)+'\n')
                (output/'annotation-ledger.json').write_text(json.dumps(all_labels,indent=2)+'\n')
                print('SHARED_LABEL',row['case'],row['arm'],pass_id,call['turn'],len(record['accepted']),len(record['rejected']),record['failure'],flush=True)
    shared_check(directory)


def shared_report(directory, output):
    import tarfile
    plan=shared_check(directory);rows=json.loads((output/'ledger.json').read_text());labels=json.loads((output/'annotation-ledger.json').read_text());points=[];summaries=[]
    for row in rows:
        for pass_id in range(plan['annotationPasses']):
            phase=next(x for x in labels if (x['case'],x['arm'],x['pass'])==(row['case'],row['arm'],pass_id))
            accepted=[e for c in phase['calls'] for e in c['accepted']]
            summaries.append({'case':row['case'],'arm':row['arm'],'pass':pass_id,
                'qualifiedPositive':sum(e['qualifiedPositive'] for e in accepted),
                'sharedPremiseDerivations':sum(e['qualifiedPositive'] and e['atom']==plan['tasks'][row['case']]['sharedAtom'] for e in accepted),
                'observedRepeatedFacts':sum(e['repeatFact'] for e in accepted),
                'observedExactRepeats':sum(e['exactRepeat'] for e in accepted),
                'newConsequencesAfterFirst':sum(e['qualifiedPositive'] and e['newConsequence'] and e['afterFirstQuestion'] for e in accepted),
                'consumedPremises':sum(e['category']=='premise_consumed' for e in accepted),
                'absenceLabels':sum(e['category']=='absence_recheck' for e in accepted),
                'rejected':sum(len(c['rejected']) for c in phase['calls']),'failedCalls':sum(c['failure'] is not None for c in phase['calls'])})
    for case in range(len(plan['tasks'])):
        case_rows=[r for r in rows if r['case']==case]
        for budget in plan['checkpoints']:
            # Completed schedules can be compared at a larger common cap; reservation failures cannot.
            if not all(r['grossTokens']>=budget or r['stop']=='schedule_complete' for r in case_rows):continue
            points.append({'case':case,'budget':budget,'arms':[{'arm':r['arm'],
                'correctDownstreamAnswers':sum(c['correct'] and c.get('atGrossTokens',budget+1)<=budget for c in r['calls']),
                'correctNewAnswersAfterFirst':sum(c['correct'] and c['turn']>0 and c.get('atGrossTokens',budget+1)<=budget for c in r['calls'])} for r in case_rows]})
    concordance=[]
    for row in rows:
        sets=[]
        for pass_id in range(plan['annotationPasses']):
            phase=next(x for x in labels if (x['case'],x['arm'],x['pass'])==(row['case'],row['arm'],pass_id))
            sets.append({json.dumps([e['turn'],e['atom'],e['premises']],sort_keys=True) for c in phase['calls'] for e in c['accepted'] if e['qualifiedPositive']})
        concordance.append({'case':row['case'],'arm':row['arm'],'intersection':len(sets[0]&sets[1]),'union':len(sets[0]|sets[1]),
            'qualifiedEpisodeJaccard':len(sets[0]&sets[1])/len(sets[0]|sets[1]) if sets[0]|sets[1] else None})
    report={'planSha256':hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),
        'solverKnownTokens':sum(c['grossTokens'] or 0 for r in rows for c in r['calls']),
        'solverUnknownUsageCalls':sum(c['grossTokens'] is None for r in rows for c in r['calls']),
        'annotationKnownTokens':sum(c['grossTokens'] or 0 for x in labels for c in x['calls']),
        'annotationUnknownUsageCalls':sum(c['modelCalled'] and c['grossTokens'] is None for x in labels for c in x['calls']),
        'trajectories':rows,'annotationSummaries':summaries,'annotationConcordance':concordance,'jointCheckpoints':points,
        'claims':'Observed literal derivation counts are lower bounds. Two passes use the same stochastic model, so concordance does not establish independent-rater reliability or completeness. No depth/optimization/causal efficacy claim follows from two small fixtures. Unused budget is not savings. Native cache reuse and model behavior are separate.'}
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    lines=['# Shared-premise Library diagnostic','',report['claims'],'',
        '| Case | Arm | Total input + all output | Correct obligations | Correct new answers after first | Stop |',
        '|---|---|---:|---:|---:|---|']
    for r in rows:lines.append(f"| {r['case']} | {r['arm']} | {r['grossTokens']} | {sum(c['correct'] for c in r['calls'])} | {sum(c['correct'] and c['turn']>0 for c in r['calls'])} | {r['stop']} {r['failure'] or ''} |")
    lines += ['','| Case / arm / annotation pass | Shared-premise derivations | Observed repeated Facts | New consequences after first | Consumed premises | Rejected labels |',
              '|---|---:|---:|---:|---:|---:|']
    for a in summaries:lines.append(f"| {a['case']} / {a['arm']} / {a['pass']} | {a['sharedPremiseDerivations']} | {a['observedRepeatedFacts']} | {a['newConsequencesAfterFirst']} | {a['consumedPremises']} | {a['rejected']} |")
    lines += ['',f"Known solver tokens: {report['solverKnownTokens']}; unknown-usage calls: {report['solverUnknownUsageCalls']}. Known annotation tokens: {report['annotationKnownTokens']}; unknown annotation calls: {report['annotationUnknownUsageCalls']}.",
        '', 'The source-bound native qualification proves support reuse across three distinct downstream obligations, alternative-support preservation, stale-handle rejection and withdrawal recomputation on this fixture. Quint correspondence and Lean premises are separate gates. The baseline/Fact/Scheme arms share the same questions and full reasoning-history replay, and do not prune alternatives. Failures remain in the ledger. No anti-repetition instruction is supplied.',
        '', 'See plan.json for relative source hashes, paper lessons, formal scope, exact tasks, independent grader and frozen annotation rules; raw.tar.gz retains inputs, native artifacts, requests, SSE events, returned thinking and rejected labels. This is a local Darwin source snapshot, not a portable binary wheel or a verified clean Git checkout reproduction.']
    (output/'report.md').write_text('\n'.join(lines)+'\n')
    doc=s.ROOT/'.cache/ascent/research-reports/agent-inference/fact-reuse-results/shared-premise-diagnostic';doc.mkdir(parents=True,exist_ok=False)
    for name in ['report.json','report.md','ledger.json','annotation-ledger.json']:shutil.copy2(output/name,doc/name)
    for name in ['plan.json','plan.sha256','qualification.json','pyo3-runtime-receipt.json','native-build-receipt.json']:shutil.copy2(directory/name,doc/name)
    with tarfile.open(doc/'raw.tar.gz','w:gz') as archive:
        archive.add(directory,arcname='frozen');archive.add(output,arcname='run')
    (doc/'integrity.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in doc.iterdir() if p.is_file()},indent=2)+'\n')
    print('SHARED_REPORT',doc,flush=True)



# Sibling branches are a research consumer, not a Library search scheduler.
BRANCH_QUESTION = ('Choose four item IDs maximizing sum of values plus bonuses for selected pairs. '
    'Every selected item must have both of its directed paths. Respect this branch\'s weight and risk limits, '
    'include at least three groups, include its required item, and omit its excluded item. '
    'Return {"selected":[IDs]}.')
BRANCH_SUBMIT = {'type':'function','name':'submit_selection','description':'Submit four selected item IDs.',
    'parameters':{'type':'object','properties':{'selected':{'type':'array','items':{'type':'integer'}}},
                  'required':['selected'],'additionalProperties':False}}
BRANCH_READ = {'type':'function','name':'read_paths',
    'description':'Read directed path conclusions from the current Scheme-checked finite source. Each pair is [from,to].',
    'parameters':{'type':'object','properties':{'pairs':{'type':'array','items':{'type':'array','items':{'type':'integer'}}}},
                  'required':['pairs'],'additionalProperties':False}}


def branch_tasks():
    tasks=[]
    for case in range(2):
        edges=[[0,1],[1,2],[2,3],[3,4],[4,5],[0,6],[6,7],[7,5]]
        items=[];needs=[]
        for i in range(16):
            start=[0,2,6][i%3]; a=20+i;b=100+i;end=200+i
            valid=i not in ([3,7,11,15] if case==0 else [2,6,10,14])
            edges.extend([[a,b],[b,end]] if valid else [[end,b],[b,a]])
            items.append({'id':i,'paths':[[start,5],[a,end]],'group':i%4,
                          'weight':5+(i*7+case*3)%14,'risk':2+(i*11+case*5)%12,
                          'value':15+(i*17+case*13)%43})
            needs.append([i,start,5,a,end])
        bonuses=[{'pair':[i,j],'value':7+(i+j)%11} for i in range(16) for j in range(i+1,16) if (i*3+j)%7==0]
        task={'id':f'sibling-search-{case}','edges':edges,'needs':needs,'items':items,'bonuses':bonuses,
              'sharedAtom':['path',0,5], 'branches':[]}
        eligible=[x['id'] for x in items if shared_truth(task,['ready',x['id']])]
        for turn in range(6):
            branch={'id':turn,'weightLimit':49+turn%3*4,'riskLimit':29+turn%3*3,
                    'required':eligible[turn], 'excluded':eligible[-1-turn]}
            feasible=branch_candidates(task,branch)
            assert len(feasible)>1 and min(s for s,_ in feasible)<max(s for s,_ in feasible)
            branch['start']=min(feasible)[1] # Deliberately nonoptimal; never adjusted after freezing.
            task['branches'].append(branch)
        tasks.append(task)
    return tasks


def branch_grade(task, branch, selected):
    if not isinstance(selected,list) or len(selected)!=4 or any(type(x) is not int for x in selected) or len(set(selected))!=4:
        return {'feasible':False,'score':None,'reason':'four distinct integer IDs required'}
    by_id={x['id']:x for x in task['items']}
    if any(x not in by_id for x in selected):return {'feasible':False,'score':None,'reason':'unknown ID'}
    chosen=[by_id[x] for x in selected]; ids=set(selected)
    checks=[all(shared_truth(task,['ready',x]) for x in ids),
            sum(x['weight'] for x in chosen)<=branch['weightLimit'],
            sum(x['risk'] for x in chosen)<=branch['riskLimit'],
            len({x['group'] for x in chosen})>=3,branch['required'] in ids,branch['excluded'] not in ids]
    if not all(checks):return {'feasible':False,'score':None,'reason':'constraint violation','checks':checks}
    score=sum(x['value'] for x in chosen)+sum(x['value'] for x in task['bonuses'] if set(x['pair'])<=ids)
    return {'feasible':True,'score':score,'reason':None}


def branch_candidates(task, branch):
    from itertools import combinations
    return [(r['score'],list(ids)) for ids in combinations(range(len(task['items'])),4)
            if (r:=branch_grade(task,branch,list(ids)))['feasible']]


def branch_qualify(engine,tasks):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    checks=[]
    for task in tasks:
        with ComputationalEvidence(engine) as store:
            source=shared_source(task);resolved=store.resolve(source,SHARED_CANDIDATE)
            assert resolved['status']=='verified'
            assert sorted(resolved['rows'])==[[i] for i in range(16) if shared_truth(task,['ready',i])]
            supports=[]
            for _ in task['branches']:
                hit=store.resolve(source,SHARED_CANDIDATE);assert hit['reused']
                observation=store.observe(source,SHARED_CANDIDATE,hit['handle'],[task['sharedAtom']],support=True)
                supports.append(observation)
            assert all(x==supports[0] for x in supports) and store.stats()['proof-builds']==1
            checks.append({'id':task['id'],'proofBuilds':1,'sharedSupportIdenticalAcrossBranches':True,'nativeStats':store.stats()})
    return checks


def branch_observe(store, task, source, *, support):
    """Read all required path atoms through the public native binding before a branch."""
    resolved=store.resolve(source,SHARED_CANDIDATE)
    assert resolved['status']=='verified'
    atoms=list(dict.fromkeys(tuple(['path',*pair]) for x in task['items'] for pair in x['paths']))
    packet=store.observe(source,SHARED_CANDIDATE,resolved['handle'],[list(a) for a in atoms],support=support)
    return packet


def branch_payload(terminal):
    calls=[x for x in terminal.get('output',[]) if x.get('type')=='function_call']
    assert len(calls)==1 and calls[0]['name']=='submit_selection','one selection tool required'
    def unique(pairs):
        result={}
        for key,value in pairs:
            assert key not in result,'duplicate selection key'
            result[key]=value
        return result
    payload=json.loads(calls[0]['arguments'],object_pairs_hook=unique)
    assert isinstance(payload,dict) and set(payload)=={'selected'},'selection schema'
    assert isinstance(payload['selected'],list) and len(payload['selected'])==4
    assert all(type(x) is int for x in payload['selected']) and len(set(payload['selected']))==4
    return payload['selected']


def branch_partial_output(terminal):
    """Only complete opaque reasoning items may be replayed after a known output limit.

    Partial messages/tool calls are not salvaged as answers. Their raw output is
    retained in the receipt. No new instructions or synthetic tool results.
    """
    assert terminal.get('status')=='incomplete'
    assert (terminal.get('incomplete_details') or {}).get('reason')=='max_output_tokens'
    output=terminal.get('output',[])
    assert output and all(x.get('type')=='reasoning' for x in output),'partial nonreasoning output'
    return copy.deepcopy(output)


def branch_submission_context(terminal):
    """Lossless visible replay for a non-thinking output phase.

    The provider may ignore opaque reasoning items with effort none. Preserve
    their exact text as an ordinary assistant message; add no instructions.
    """
    items=branch_partial_output(terminal) if terminal.get('status')=='incomplete' else terminal['output'];parts=[]
    for item in items:
        for part in item.get('content',[]):
            assert item.get('type') in ('reasoning','message') and part.get('type') in ('reasoning_text','output_text'),'unsupported submission content'
            parts.append(part['text'])
    text=''.join(parts);assert text,'no visible reasoning to submit'
    return [{'type':'message','role':'assistant','content':[{'type':'output_text','text':text}]}]


def branch_literal_episodes(text, task, supplied, prior, turn, step):
    """Exhaustive text partition plus conservative explicit-chain observations.

    The scanner has finite grammars, not a general natural-language parser.
    Every character is assigned to a line; unresolved path language is visible.
    It never constructs a missing edge from the fixture to finish a quote.
    """
    import re
    lines=[];offset=0;events=[]
    arrow=re.compile(r'(?<![\w.])\d+(?:\s*(?:->|→|⇒)\s*\d+)+')
    pairs=re.compile(r'\[\s*(\d+)\s*,\s*(\d+)\s*\]')
    via=re.compile(r'(\d+)\s*(?:->|→|to)\s*(\d+)\s+via\s+((?:\d+\s*,\s*)+\d+)',re.I)
    semantic=re.compile(r'\b(path|paths|reachab\w*|valid|invalid|infeasible|absent|ready|edge|edges|exists|via|true|false)\b|->|→',re.I)
    for line in text.splitlines(keepends=True):
        chains=[]
        for match in arrow.finditer(line):
            ns=[int(x) for x in re.findall(r'\d+',match.group())]
            if len(ns)>=3:chains.append((match.start(),match.end(),ns))
        for match in via.finditer(line):
            ns=[int(x) for x in re.findall(r'\d+',match.group(3))]
            if len(ns)>=3 and ns[0]==int(match.group(1)) and ns[-1]==int(match.group(2)):
                chains.append((match.start(),match.end(),ns))
        matches=list(pairs.finditer(line))
        for i,m in enumerate(matches):
            # A maximal adjacent literal edge list must itself form a chain.
            if i and re.fullmatch(r'[\s,;]*',line[matches[i-1].end():m.start()]):continue
            j=i;ns=[int(m.group(1)),int(m.group(2))]
            while j+1<len(matches) and re.fullmatch(r'[\s,;]*',line[matches[j].end():matches[j+1].start()]) and int(matches[j+1].group(1))==ns[-1]:
                j+=1;ns.append(int(matches[j].group(2)))
            if j>i and semantic.search(line):chains.append((m.start(),matches[j].end(),ns))
        seen=set()
        for start,end,ns in sorted(chains):
            atom=['path',ns[0],ns[-1]];premises=[['edge',a,b] for a,b in zip(ns,ns[1:])]
            key=(start,end,tuple(ns))
            if key in seen:continue
            seen.add(key)
            if not all(shared_truth(task,x) for x in premises):continue
            old=[e for e in prior+events if e['atom']==atom]
            event={'quote':line[start:end],'span':[offset+start,offset+end],'atom':atom,'premises':premises,
                   'turn':turn,'step':step,'qualifiedPositive':True,
                   'crossBranchRepeat':any(e['turn']!=turn for e in old),
                   'sameBranchRepeat':any(e['turn']==turn and e['step']!=step for e in old),
                   'withinResponseRepeat':any(e['turn']==turn and e['step']==step for e in old),
                   'exactRepeat':any(e['premises']==premises for e in old),
                   'suppliedPremiseRederived':atom in supplied,
                   'newConsequence':not old and atom not in supplied}
            # Overlapping textual encodings are one occurrence, not two derivations.
            if any(e['span'][0]<event['span'][1] and event['span'][0]<e['span'][1] for e in events):continue
            events.append(event)
        line_events=[e for e in events if offset<=e['span'][0]<offset+len(line)]
        lines.append({'span':[offset,offset+len(line)],'quote':line,
                      'category':'explicit_chain' if line_events else 'unresolved_semantic' if semantic.search(line) else 'other_visible_text'})
        offset+=len(line)
    assert offset==len(text) and ''.join(l['quote'] for l in lines)==text
    return {'characters':len(text),'coveredCharacters':offset,'partitions':lines,'episodes':events,
            'unresolvedSemanticLines':sum(l['category']=='unresolved_semantic' for l in lines)}


def branch_label(directory, output):
    plan=shared_check(directory);rows=json.loads((output/'ledger.json').read_text());labels=[]
    dest=output/'annotations';dest.mkdir(exist_ok=False)
    for row in rows:
        prior=[];record={'case':row['case'],'arm':row['arm'],'pass':0,'calls':[]};labels.append(record)
        for call in row['calls']:
            folder=output/'calls'/f"{row['case']}-{row['arm']}"/f"{call['turn']}-{call['step']}"
            text=(folder/'thinking.txt').read_text();assert hashlib.sha256(text.encode()).hexdigest()==call['thinkingSha256']
            coverage=branch_literal_episodes(text,plan['tasks'][row['case']],call['suppliedAtoms'],prior,call['turn'],call['step'])
            out=dest/f"{row['case']}-{row['arm']}-{call['turn']}-{call['step']}.json"
            out.write_text(json.dumps(coverage,indent=2)+'\n');prior.extend(coverage['episodes'])
            record['calls'].append({'turn':call['turn'],'step':call['step'],'modelCalled':False,'grossTokens':0,'failure':None,
                'accepted':[dict(e,category='positive_derivation',new_residual=False,afterFirstQuestion=call['turn']>0) for e in coverage['episodes']],
                'rejected':[],'coverageFile':str(out.relative_to(output)),
                'coveredCharacters':coverage['coveredCharacters'],'characters':coverage['characters'],
                'unresolvedSemanticLines':coverage['unresolvedSemanticLines']})
    (output/'annotation-ledger.json').write_text(json.dumps(labels,indent=2)+'\n')
    print('BRANCH_LITERAL_COVERAGE_OK',sum(c['characters'] for r in labels for c in r['calls']),flush=True)



SEMANTIC_LINE_CATEGORIES = ['premise_use', 'path_derivation', 'absence_argument', 'optimization', 'other', 'unresolved']


def branch_semantic_validate(text, payload):
    """Require a label for every actual line; missing/unclear semantics fail closed."""
    assert isinstance(payload,dict) and set(payload)=={'lineCategories','episodes'}, 'semantic schema'
    lines=text.splitlines(keepends=True); labels=payload['lineCategories']
    assert isinstance(labels,list) and len(labels)==len(lines), 'semantic line coverage'
    spans=[];offset=0
    for i,(line,category) in enumerate(zip(lines,labels)):
        assert category in SEMANTIC_LINE_CATEGORIES, 'unknown semantic category'
        spans.append({'line':i,'span':[offset,offset+len(line)],'category':category});offset+=len(line)
    assert offset==len(text)
    return spans



def branch_semantic_partition(text, episodes):
    """Code owns coverage; model proposals own only independently admitted quotes."""
    partitions=[];cursor=0
    for e in episodes:
        start,end=e['span']
        assert cursor<=start<end<=len(text) and text[start:end]==e['quote'], 'quote coverage shape'
        if cursor<start:partitions.append({'span':[cursor,start],'category':'unreviewed_semantics'})
        partitions.append({'span':[start,end],'category':'admitted_quote_proposal'});cursor=end
    if cursor<len(text):partitions.append({'span':[cursor,len(text)],'category':'unreviewed_semantics'})
    assert sum(p['span'][1]-p['span'][0] for p in partitions)==len(text)
    return partitions

def branch_semantic_summary(text, episodes):
    """Separate admitted quote evidence from exhaustive repetition claims.

    A negative assertion's truth does not certify a new absence argument.
    Arithmetic and mentions do not certify exploration depth. Unreviewed text
    leaves whole-trace repetition unknown even when no accepted proof repeats.
    """
    partition=branch_semantic_partition(text,episodes)
    counts={k:0 for k in ('positive_fact_use','negative_fact_use',
        'positive_reconstruction_proposal','new_positive_inference_proposal',
        'negative_statement_unresolved','other_proposal')}
    for e in episodes:
        category=e['category']
        if category=='premise_consumed':role='positive_fact_use'
        elif category=='absent_premise_consumed':role='negative_fact_use'
        elif category=='absence_recheck':role='negative_statement_unresolved'
        elif e.get('qualifiedPositive'):
            role=('new_positive_inference_proposal' if e.get('newConsequence')
                  else 'positive_reconstruction_proposal')
        else:role='other_proposal'
        counts[role]+=1
    return {'admittedProposalCounts':counts,'characterPartition':partition,
        'unreviewedCharacters':sum(p['span'][1]-p['span'][0] for p in partition
                                  if p['category']=='unreviewed_semantics'),
        'wholeTraceRepeatedDerivations':None,'negativeRederivations':None,
        'explorationDepth':None,'fullSemanticRecallCertified':False}

SEMANTIC_BLOCK_TAGS = ['positive_fact_use','negative_fact_use','positive_derivation',
    'negative_argument','downstream_inference','optimization','task_interpretation','unclear']

def branch_semantic_blocks(text, limit):
    """Own immutable review boundaries locally; annotators never count lines."""
    assert type(limit) is int and limit>0
    blocks=[];start=0
    while start<len(text):
        end=min(start+limit,len(text))
        if end<len(text):
            boundary=text.rfind('\n',start+limit//2,end)
            if boundary>=0:end=boundary+1
        blocks.append({'id':len(blocks),'span':[start,end],'text':text[start:end]})
        start=end
    assert ''.join(b['text'] for b in blocks)==text
    return blocks

def branch_semantic_block_admit(blocks, proposals):
    """Coverage of review proposals is distinct from semantic recall or truth."""
    assert isinstance(proposals,list),'block review schema'
    indexed={}
    for p in proposals:
        assert set(p)=={'id','tags'} and type(p['id']) is int,'block review schema'
        assert 0<=p['id']<len(blocks) and p['id'] not in indexed,'duplicate or unknown block'
        assert isinstance(p['tags'],list) and p['tags'] and len(set(p['tags']))==len(p['tags']),'block tags shape'
        assert all(t in SEMANTIC_BLOCK_TAGS for t in p['tags']),'unknown semantic tag'
        indexed[p['id']]=p['tags']
    assert len(indexed)==len(blocks),'missing block review; unreviewed is not zero'
    return [{'id':b['id'],'span':b['span'],'tags':indexed[b['id']],
             'status':'unclear' if 'unclear' in indexed[b['id']] else 'model_review_proposal'} for b in blocks]

def branch_semantic_label(directory, output):
    """Blind model proposal plus local truth/span admission; never solver feedback.

    Line classifications are proposals, not verified semantics. Atomic inference
    episodes undergo the existing independent directed-truth and stated-premise
    validation. One correlated model pass cannot establish annotation recall.
    """
    plan=shared_check(directory);rows=json.loads((output/'ledger.json').read_text());ledger=[];calls=0
    dest=output/'semantic-annotations';dest.mkdir(exist_ok=False)
    for row in rows:
        task=plan['tasks'][row['case']];prior=[]
        for c in row['calls']:
            if c['step']!=0:continue
            folder=output/'calls'/f"{row['case']}-{row['arm']}"/f"{c['turn']}-{c['step']}"
            text=(folder/'thinking.txt').read_text();blind=hashlib.sha256(text.encode()).hexdigest()
            out=dest/blind;out.mkdir(exist_ok=False)
            rec={'case':row['case'],'arm':row['arm'],'turn':c['turn'],'thinkingSha256':blind,'modelCalled':False,
                 'grossTokens':None,'failure':None,'accepted':[],'rejected':[],'lineProposals':[],'characters':len(text)};ledger.append(rec)
            try:
                assert text, 'no thinking to annotate'
                assert calls<plan['maxSemanticCalls'], 'semantic call bound; unreviewed trace retained'
                tool=plan['semanticTool']
                blocks=branch_semantic_blocks(text,plan['semanticReviewBlockChars']) if plan.get('semanticReviewBlockChars') else None
                reasoning={'reasoningBlocks':[{'id':b['id'],'text':b['text']} for b in blocks]} if blocks is not None else {'reasoningText':text}
                req={'model':plan['model'],'input':[{'role':'user','content':json.dumps({'edges':task['edges'],'needs':task['needs'],
                    **reasoning,
                    'earlierConclusions':[o['conclusion'] for o in (c.get('entryEvidence') or {}).get('observations',[])]},separators=(',',':'))}],
                    'instructions':plan['semanticRubric'],'tools':[tool],'tool_choice':{'type':'function','name':'annotate'},
                    'reasoning':{'effort':'none'},'max_output_tokens':plan['semanticOutputCap'],'stream':True,'store':False}
                (out/'request.json').write_text(json.dumps(req,indent=2)+'\n');rec['modelCalled']=True;calls+=1
                _,meta=provider(req,provider_key(),out/'response.json');terminal=meta.get('terminal') or {};u=terminal.get('usage')
                if isinstance(u,dict):rec['usage']=u;rec['grossTokens']=u['input_tokens']+u['output_tokens']
                assert not meta.get('error') and terminal.get('status')=='completed', 'semantic provider incomplete or failed'
                tc=terminal.get('output',[]);tc=[x for x in tc if x.get('type')=='function_call']
                assert len(tc)==1 and tc[0]['name']=='annotate', 'semantic submission shape'
                payload=json.loads(tc[0]['arguments'])
                assert set(payload)==({'episodes','blocks'} if blocks is not None else {'episodes'}) and isinstance(payload['episodes'],list),'semantic quote schema'
                if blocks is not None:
                    rec['blockReviews']=branch_semantic_block_admit(blocks,payload['blocks'])
                    rec['reviewProposalCoverageComplete']=True
                    rec['unclearBlockCharacters']=sum(b['span'][1]-b['span'][0] for b in rec['blockReviews'] if b['status']=='unclear')
                for item in payload['episodes']:
                    try:
                        e=shared_validate_label(text,item,task,c['suppliedAtoms'],prior,
                            supplied_absent=[o['conclusion']['atom'] for o in (c.get('entryEvidence') or {}).get('observations',[]) if o['conclusion']['status']=='finite-absent'])
                        e.update(turn=c['turn'],step=c['step'])
                        old=[x for x in prior if x['qualifiedPositive'] and x['atom']==e['atom']]
                        e['crossBranchRepeat']=any(x['turn']!=c['turn'] for x in old)
                        assert not rec['accepted'] or e['span'][0]>=rec['accepted'][-1]['span'][1],'overlapping or unordered quote'
                        rec['accepted'].append(e);prior.append(e)
                    except Exception as error:rec['rejected'].append({'proposal':item,'failure':str(error)})
            except Exception as error:rec['failure']=str(error)
            rec['characterPartition']=branch_semantic_partition(text,rec['accepted'])
            rec['unreviewedCharacters']=sum(p['span'][1]-p['span'][0] for p in rec['characterPartition'] if p['category']=='unreviewed_semantics')
            rec['fullSemanticRecallCertified']=False
            rec.setdefault('reviewProposalCoverageComplete',False)
            rec['notReviewedByBlockProposalsCharacters']=0 if rec['reviewProposalCoverageComplete'] else len(text)
            rec['semanticSummary']=branch_semantic_summary(text,rec['accepted'])
            (out/'receipt.json').write_text(json.dumps(rec,indent=2)+'\n')
            (output/'semantic-ledger.json').write_text(json.dumps(ledger,indent=2)+'\n')
            print('SEMANTIC_REVIEW',row['case'],row['arm'],c['turn'],len(rec['accepted']),len(rec['rejected']),rec['failure'],flush=True)
    shared_check(directory)

def branch_freeze(library, directory):
    # Reuse the existing source/binary freezer and its native/formal gates.
    tasks=branch_tasks();shared_freeze(library,directory,search_tasks=tasks)
    plan=json.loads((directory/'plan.json').read_text())
    plan.update(question=BRANCH_QUESTION,tasks=tasks,tool=BRANCH_SUBMIT,readTool=BRANCH_READ,
                experiment='sibling-search',maxCallsPerBranch=2, evidenceAtBranchEntry=True, maxTotalSolverCalls=18,
                artifactDirectory='branch-complete', maxOutputTokens=32768, requireCompleteThinking=True, compactEvidence=True, finalizationOutputCap=256,
                annotationMode='literal-partition',annotationPasses=1,
                annotationRubric='Frozen literal grammar: arrow chains with at least three nodes; adjacent explicit edge-pair lists; endpoint-preserving via node lists. Truth and direction checked independently. One occurrence per overlapping encoding. All lines partitioned, unresolved semantic lines retained. No unseen premise constructed.',
                annotationTool=None,
                outputProtocol='Automatic tool choice, unchanged low reasoning. Output cap uses all remaining cell budget after conservative input reservation. Never disable thinking to salvage truncation: incomplete first output is a retained censored failure. A completed plain response may use the existing non-thinking structured transport only if its entire replay input and output fit the same total ceiling.',
                annotationCoverage='Every visible character partitioned; only literal ordered chains counted. Unresolved semantic lines retained; syntactic coverage is not exhaustive semantic certification.',
                historyPolicy='Each sibling forks the same root task. No sibling reasoning is imported into another sibling; identical policy in all arms. Native store spans siblings.',
                annotationRules=plan['annotationRules']+' Repetition is split into within-response, same-branch and cross-branch dimensions. Supplied evidence is only evidence returned before the labeled response, never later tool results.')
    plan['independentJudge']={'algorithm':'Enumerate all four-item subsets independently of Scheme; directed BFS, sum resource constraints, group count and exact pair bonus scoring.',
                             'frozenOptima':[[max(branch_candidates(t,b))[0] for b in t['branches']] for t in tasks]}
    semantic_tool=copy.deepcopy(SHARED_LABEL_TOOL)
    # Code owns small review blocks. Quotes retain the existing admission rules.
    semantic_tool['parameters']['properties']['blocks']={'type':'array','items':{
        'type':'object','properties':{'id':{'type':'integer'},'tags':{'type':'array',
            'items':{'type':'string','enum':SEMANTIC_BLOCK_TAGS}}},
        'required':['id','tags'],'additionalProperties':False}}
    semantic_tool['parameters']['required']=['episodes','blocks']
    plan.update(semanticTool=semantic_tool,maxSemanticCalls=18,semanticOutputCap=8192,
                semanticReviewBlockChars=1800,
                semanticRubric=SHARED_RUBRIC+' absent_premise_consumed is use of an earlier finite-absent conclusion, not a new absence proof: quote must explicitly refer to native/given evidence; unknown is never an absent premise. Read every supplied reasoningBlock; return each block id exactly once with all applicable tags: positive_fact_use, negative_fact_use, positive_derivation, negative_argument, downstream_inference, optimization, task_interpretation, unclear. Reading or listing supplied conclusions is evidence use, not reconstruction. Applying path facts to item feasibility is downstream inference, not proving those paths again. A negative assertion alone is not an absence argument; unclear use-versus-recheck must include unclear. For episodes, concatenate block texts in their given order and use exact contiguous quotes and zero-based occurrence within that full text. Do not enumerate lines or invent offsets. Do not emit arithmetic episodes. Blocks are review proposals, not certified recall; unsupported or ambiguous content remains unknown. No solver receives these annotation instructions.')
    plan['branchQualification']=json.loads((directory/'qualification.json').read_text())['branchTaskChecks']
    # No model trial can begin from a dirty or incomplete producer checkout.
    import subprocess
    status=subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=s.ROOT,text=True)
    assert not status,'clean producer required: '+status
    plan['sourceState']={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=s.ROOT,text=True).strip(),
                         'dirtySourceSnapshot':False,'cleanCheckoutReproductionVerified':True,
                         'scope':'Local clean checkout rebuild and native qualification; not a cross-machine or remote CI claim.'}
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    (directory/'plan.sha256').write_text(hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest()+'\n')
    shared_committed_check(directory,directory/'committed-gate')
    print('BRANCH_FREEZE_OK',flush=True)


def branch_input_reservation(request, prior_usage, additions, padding):
    # Replayed output is already measured in the preceding input + all-output usage.
    # Only genuinely new paired tool results use the conservative UTF-8 bound.
    measured = (len(json.dumps(request,ensure_ascii=False).encode()) if prior_usage is None else
                prior_usage+sum(len(json.dumps(x,ensure_ascii=False).encode()) for x in additions))
    return measured+padding


def branch_entry_reservation(request, prior_request, prior_input, padding):
    if prior_request is None:return branch_input_reservation(request,None,[],padding)
    # Only a changed branch record is new; all other request/context bytes must match.
    a={k:v for k,v in prior_request.items() if k not in ('input','max_output_tokens')}
    b={k:v for k,v in request.items() if k not in ('input','max_output_tokens')}
    old=json.loads(prior_request['input'][0]['content']);new=json.loads(request['input'][0]['content'])
    if a!=b or {k:v for k,v in old.items() if k!='branch'}!={k:v for k,v in new.items() if k!='branch'}:
        return branch_input_reservation(request,None,[],padding)
    return prior_input+sum(len(json.dumps(c['branch'],ensure_ascii=False).encode()) for c in (old,new))+padding


def branch_qualification_request(plan, fixture):
    request=copy.deepcopy(fixture['request']);request['input']+=branch_submission_context(fixture['terminal'])
    request.update(reasoning={'effort':'none'},tools=[plan['tool']],
                   tool_choice={'type':'function','name':'submit_selection'},max_output_tokens=plan['finalizationOutputCap'])
    return request


def branch_import_output_qualification(directory, output):
    """Reuse actual transport receipts only for byte-identical qualification requests."""
    plan=shared_check(directory);fixture=json.loads((directory/'inputs/t/research/output-check-fixture.json').read_text())
    expected=branch_qualification_request(plan,fixture)
    record=json.loads((output/'receipt.json').read_text());actual=json.loads((output/'request.json').read_text())
    terminal=json.loads((output/'response.json').read_text())['terminal']
    assert record['passed'] and expected==actual and record['usage']==terminal['usage']
    assert terminal['status']=='completed' and branch_payload(terminal)==record['selected']
    assert terminal['usage']['input_tokens']>=fixture['terminal']['usage']['input_tokens']+1024
    assert record['fixtureSha256']==plan['inputs']['t/research/output-check-fixture.json']
    linked={**record,'acceptedForPlanSha256':hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),
            'qualificationRequestSha256':hashlib.sha256((output/'request.json').read_bytes()).hexdigest(),
            'reuseScope':'Byte-identical nonthinking transport request only; does not qualify thinking tool choice or native semantics'}
    (directory/'output-qualification.json').write_text(json.dumps(linked,indent=2)+'\n')
    print('OUTPUT_QUALIFICATION_REQUEST_IDENTITY_OK',flush=True)


def branch_output_qualify(directory, output):
    """Explicit paid transport gate; clean-rebuild never calls this function."""
    plan=shared_check(directory);output.mkdir(parents=True,exist_ok=False)
    fixture=json.loads((directory/'inputs/t/research/output-check-fixture.json').read_text())
    request=branch_qualification_request(plan,fixture)
    bound=branch_input_reservation(request,None,[],plan['inputPadding'])
    (output/'request.json').write_text(json.dumps(request,indent=2)+'\n')
    record={'passed':False,'planSha256':hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),
            'fixtureSha256':plan['inputs']['t/research/output-check-fixture.json'],
            'costBoundary':'Transport qualification separately charged, not a solver trajectory','inputReservation':bound,'usage':None,'failure':None}
    try:
        _,meta=provider(request,provider_key(),output/'response.json');terminal=meta.get('terminal') or {}
        record['usage']=terminal.get('usage')
        assert not meta.get('error') and terminal.get('status')=='completed','output qualification provider failure'
        u=terminal['usage'];assert u['input_tokens']<=bound and u['output_tokens']<=plan['finalizationOutputCap']
        baseline_input=fixture['terminal']['usage']['input_tokens']
        assert u['input_tokens']>=baseline_input+1024,'historical thinking not reflected in input usage'
        record['historicalThinkingInputIncrement']=u['input_tokens']-baseline_input
        record['selected']=branch_payload(terminal);record['passed']=True
    except Exception as error:record['failure']=str(error)
    (output/'receipt.json').write_text(json.dumps(record,indent=2)+'\n')
    (directory/'output-qualification.json').write_text(json.dumps(record,indent=2)+'\n')
    assert record['passed'],record['failure']
    print('OUTPUT_FINALIZATION_QUALIFIED',flush=True)


def branch_live(directory, output):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    plan=shared_check(directory);assert plan['experiment']=='sibling-search'
    qualification=json.loads((directory/'output-qualification.json').read_text())
    assert qualification['passed'] and qualification.get('acceptedForPlanSha256',qualification['planSha256'])==hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),'live output gate required'
    output.mkdir(parents=True,exist_ok=False);rows=[]
    def save():(output/'ledger.json').write_text(json.dumps(rows,indent=2)+'\n')
    with ReasoningRuntime() as engine:
        for case,task in enumerate(plan['tasks']):
            for arm in plan['orders'][case]:
                row={'case':case,'arm':arm,'calls':[],'branches':[],'grossTokens':0,'stop':None,'failure':None};rows.append(row);save()
                with ComputationalEvidence(engine) as store:
                    source=shared_source(task);resolved=None;entry_request=None;entry_input=None
                    if arm!='baseline':
                        resolved=store.resolve(source,SHARED_CANDIDATE)
                        assert resolved['status']=='verified'
                    for branch in task['branches']:
                        # Every arm starts from the same known feasible nonoptimal selection.
                        context={'question':plan['question'],'task':{'edges':task['edges'],'items':task['items'],'bonuses':task['bonuses']},'branch':branch}
                        supplied=[];entry_packet=None
                        if plan.get('evidenceAtBranchEntry') and arm!='baseline':
                            entry_packet=branch_observe(store,task,source,support=arm=='scheme')
                            context['nativeEvidence']=entry_packet
                            if plan.get('compactEvidence'):
                                from agentic_ai_lab_runtime.reasoning import compact_observation, expand_observation
                                context['nativeEvidence']=compact_observation(entry_packet)
                                assert expand_observation(context['nativeEvidence'])==entry_packet
                            supplied=[o['conclusion']['atom'] for o in entry_packet['observations'] if o['conclusion']['status']=='verified']
                        history=ResponseHistory(json.dumps(context,separators=(',',':')));done=False;prior_usage=None;new_results=[]
                        try:
                            for step in range(plan['maxCallsPerBranch']):
                                if sum(len(r['calls']) for r in rows)>=plan['maxTotalSolverCalls']:
                                    row['stop']='global_call_bound';break
                                req={'model':plan['model'],'input':history.input(),'tools':[plan['tool']]+([plan['readTool']] if arm!='baseline' else []),
                                     'tool_choice':'auto' if step==0 else {'type':'function','name':'submit_selection'},
                                     'reasoning':{'effort':plan['reasoningEffort'] if step==0 else 'none'},'stream':True,'store':False}
                                if plan.get('evidenceAtBranchEntry'):req['tools']=[plan['tool']]
                                bound=(branch_entry_reservation(req,entry_request,entry_input,plan['inputPadding']) if step==0 else
                                       branch_input_reservation(req,prior_usage,new_results,plan['inputPadding']))
                                available=plan['totalBudget']-row['grossTokens']-bound
                                reserve=bound+plan['maxOutputTokens']+plan['inputPadding']+plan['finalizationOutputCap'] if step==0 and not plan.get('requireCompleteThinking') else 0
                                cap=min(plan['maxOutputTokens'] if step==0 else plan['finalizationOutputCap'],available-reserve)
                                if cap<(plan['minimumOutputTokens'] if step==0 else plan['finalizationOutputCap']):row['stop']='budget_reservation';break
                                req['max_output_tokens']=cap
                                folder=output/'calls'/f'{case}-{arm}'/f"{branch['id']}-{step}";folder.mkdir(parents=True)
                                rec={'turn':branch['id'],'step':step,'usage':None,'grossTokens':None,'failure':None,'suppliedAtoms':copy.deepcopy(supplied),'inputReservation':bound,'outputCap':cap,'nativePacket':None,'entryEvidence':entry_packet,'suppliedFacts':copy.deepcopy([o['conclusion'] for o in (entry_packet or {}).get('observations',[])]),'outputTruncated':False}
                                row['calls'].append(rec);save();(folder/'request.json').write_text(json.dumps(req,indent=2)+'\n')
                                _,meta=provider(req,provider_key(),folder/'response.json');terminal=meta.get('terminal') or {};u=terminal.get('usage')
                                rec.update(status=terminal.get('status'),usage=u,providerError=meta.get('error'),incompleteDetails=terminal.get('incomplete_details'))
                                thinking=''.join(p.get('text','') for x in terminal.get('output',[]) if x.get('type')=='reasoning' for p in x.get('content',[]) if p.get('type')=='reasoning_text')
                                (folder/'thinking.txt').write_text(thinking);rec['thinkingSha256']=hashlib.sha256(thinking.encode()).hexdigest()
                                assert isinstance(u,dict) and all(type(u.get(k)) is int and u[k]>=0 for k in ('input_tokens','output_tokens')),'unknown usage'
                                rec['grossTokens']=u['input_tokens']+u['output_tokens'];row['grossTokens']+=rec['grossTokens'];rec['atGrossTokens']=row['grossTokens']
                                if step==0:entry_request=copy.deepcopy(req);entry_input=u['input_tokens']
                                assert u['input_tokens']<=bound and u['output_tokens']<=cap and row['grossTokens']<=plan['totalBudget'],'budget violation'
                                assert not meta.get('error'),'provider failure'
                                if terminal.get('status')=='incomplete':
                                    assert step==0,'finalization incomplete'
                                    rec['outputTruncated']=True
                                    if plan.get('requireCompleteThinking'):
                                        raise ValueError('thinking incomplete under total budget; no nonthinking salvage')
                                    history.append_response({'output':branch_submission_context(terminal)})
                                    rec['outputTruncated']=True;rec['failure']='thinking max_output_tokens; finalization scheduled'
                                    prior_usage=rec['grossTokens'];new_results=[]
                                    (folder/'receipt.json').write_text(json.dumps(rec,indent=2)+'\n');save()
                                    print('BRANCH_CHECKPOINT',case,arm,branch['id'],row['grossTokens'],flush=True)
                                    continue
                                assert terminal.get('status')=='completed','provider incomplete'
                                if step==0 and not any(x.get('type')=='function_call' for x in terminal['output']):
                                    history.append_response({'output':branch_submission_context(terminal)})
                                    rec['submissionContinuation']=True;prior_usage=rec['grossTokens'];new_results=[]
                                    (folder/'receipt.json').write_text(json.dumps(rec,indent=2)+'\n');save();continue
                                calls=[x for x in terminal['output'] if x['type']=='function_call'];history.append_response(terminal)
                                if calls and all(x['name']=='read_paths' for x in calls):
                                    assert arm!='baseline' and step+1<plan['maxCallsPerBranch'],'unresolved read at call bound'
                                    packets=[]
                                    for c in calls:
                                        args=json.loads(c['arguments']);assert set(args)=={'pairs'} and isinstance(args['pairs'],list) and 0<len(args['pairs'])<=32
                                        assert all(isinstance(p,list) and len(p)==2 and all(type(n) is int for n in p) for p in args['pairs']),'unknown path request'
                                        hit=store.resolve(source,SHARED_CANDIDATE);assert hit['status']=='verified'
                                        packet=store.observe(source,SHARED_CANDIDATE,hit['handle'],[['path',*p] for p in args['pairs']],support=arm=='scheme')
                                        for o in packet['observations']:
                                            f=o['conclusion'];assert f['status'] in ('verified','finite-absent')
                                            assert (f['status']=='verified')==shared_truth(task,f['atom'])
                                            if f['status']=='verified' and f['atom'] not in supplied:supplied.append(f['atom'])
                                        history.append_result(c['call_id'],packet);packets.append(packet)
                                    rec['nativePacket']={'returnedToolPackets':packets,'nativeStats':store.stats()}
                                    prior_usage=rec['grossTokens'];new_results=history.snapshot()[-len(calls):]
                                else:
                                    if calls:
                                        assert len(calls)==1 and calls[0]['name']=='submit_selection','mixed or unknown tool calls'
                                        payload=json.loads(calls[0]['arguments'])
                                    else:
                                        messages=[p['text'] for x in terminal['output'] if x['type']=='message' for p in x.get('content',[]) if p.get('type')=='output_text'];assert len(messages)==1,'one answer required'
                                        payload=json.loads(messages[0])
                                    assert isinstance(payload,dict) and set(payload)=={'selected'},'selection schema'
                                    selected=branch_payload(terminal);grade=branch_grade(task,branch,selected)
                                    for c in calls:history.append_result(c['call_id'],{'recorded':True})
                                    row['branches'].append({'turn':branch['id'],'selected':selected,'grade':grade,'atGrossTokens':row['grossTokens'],'startScore':branch_grade(task,branch,branch['start'])['score']})
                                    done=True
                                (folder/'receipt.json').write_text(json.dumps(rec,indent=2)+'\n');save()
                                print('BRANCH_CALL',case,arm,branch['id'],step,row['grossTokens'],'done',done,flush=True)
                                if done:break
                            if row['stop'] in ('budget_reservation','global_call_bound'):break
                            assert done,'branch did not submit before call bound'
                        except Exception as error:
                            row['failure']=str(error);row['stop']='failure'
                            if row['calls']:
                                row['calls'][-1]['failure']=str(error)
                                (folder/'receipt.json').write_text(json.dumps(row['calls'][-1],indent=2)+'\n')
                            break
                        finally:save()
                    row['stop']=row['stop'] or 'schedule_complete';row['unusedBudget']=plan['totalBudget']-row['grossTokens'];row['nativeStats']=store.stats();save()
    shared_check(directory)
    print('BRANCH_LIVE_COMPLETE',flush=True)


def branch_report(directory, output):
    import tarfile
    plan=shared_check(directory);rows=json.loads((output/'ledger.json').read_text());labels=json.loads((output/'annotation-ledger.json').read_text());summaries=[]
    for row in rows:
        task=plan['tasks'][row['case']]; grades={b['turn']:b for b in row['branches']}; optima=plan['independentJudge']['frozenOptima'][row['case']]
        starts=[branch_grade(task,b,b['start'])['score'] for b in task['branches']]
        achieved=[grades[i]['grade']['score'] if i in grades and grades[i]['grade']['feasible'] else starts[i] for i in range(len(starts))]
        summary={'case':row['case'],'arm':row['arm'],'grossTokens':row['grossTokens'],'stop':row['stop'],'failure':row['failure'],
                 'submittedBranches':len(grades),'feasibleSubmittedBranches':sum(b['grade']['feasible'] for b in row['branches']),
                 'optimalSubmittedBranches':sum(b['grade']['feasible'] and b['grade']['score']==optima[b['turn']] for b in row['branches']),
                 'truncatedThinkingCalls':sum(c.get('outputTruncated',False) for c in row['calls']),
                 'finalizationCalls':sum(c['step']>0 for c in row['calls']),
                 'startScores':starts,'incumbentScores':achieved,'optimumScores':optima,
                 'meanNormalizedImprovement':sum((a-s)/(o-s) for a,s,o in zip(achieved,starts,optima))/len(starts),
                 'nativeStats':row['nativeStats'],'unusedBudget':row['unusedBudget'],'annotation':[]}
        for phase in [x for x in labels if (x['case'],x['arm'])==(row['case'],row['arm'])]:
            accepted=[e for c in phase['calls'] for e in c['accepted']]
            summary['annotation'].append({'pass':phase['pass'],'qualifiedDerivations':sum(e['qualifiedPositive'] for e in accepted),
                'crossBranchRepeats':sum(e.get('crossBranchRepeat',False) for e in accepted),
                'sameBranchRepeats':sum(e.get('sameBranchRepeat',False) for e in accepted),
                'withinResponseRepeats':sum(e.get('withinResponseRepeat',False) for e in accepted),
                'suppliedPremiseRederivations':sum(e.get('suppliedPremiseRederived',False) for e in accepted),
                'consumedPremises':sum(e['category']=='premise_consumed' for e in accepted),
                'newConsequencesAfterFirst':sum(e['qualifiedPositive'] and e['newConsequence'] and e['afterFirstQuestion'] for e in accepted),
                'coveredCharacters':sum(c.get('coveredCharacters',0) for c in phase['calls']),
                'visibleCharacters':sum(c.get('characters',0) for c in phase['calls']),
                'unresolvedSemanticLines':sum(c.get('unresolvedSemanticLines',0) for c in phase['calls']),
                'rejectedLabels':sum(len(c['rejected']) for c in phase['calls']),'failedCalls':sum(c['failure'] is not None for c in phase['calls'])})
        summaries.append(summary)
    checkpoints=[]
    for case in range(2):
        for cap in plan['checkpoints']:
            data=[]
            for row in [r for r in rows if r['case']==case]:
                task=plan['tasks'][case];included={b['turn']:b for b in row['branches'] if b['atGrossTokens']<=cap}
                scores=[included[b['id']]['grade']['score'] if b['id'] in included and included[b['id']]['grade']['feasible'] else branch_grade(task,b,b['start'])['score'] for b in task['branches']]
                data.append({'arm':row['arm'],'submittedBranches':len(included),'incumbentScores':scores})
            checkpoints.append({'case':case,'cap':cap,'arms':data})
    report={'planSha256':hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),'summaries':summaries,'checkpoints':checkpoints,
            'solverKnownTokens':sum(c['grossTokens'] or 0 for r in rows for c in r['calls']),
            'solverUnknownUsageCalls':sum(c['grossTokens'] is None for r in rows for c in r['calls']),
            'annotationKnownTokens':sum(c['grossTokens'] or 0 for x in labels for c in x['calls']),
            'annotationUnknownUsageCalls':sum(c['modelCalled'] and c['grossTokens'] is None for x in labels for c in x['calls']),
            'claims':'Two finite fixtures and one stochastic trajectory per cell. Native reuse, model tool consumption, literal derivation counts and optimization quality are separate. Literal chain counts have limited grammar recall; complete character partition does not certify semantic completeness. Unresolved lines are retained. Thinking truncated at a checkpoint remains censored even if finalization returns an answer. Unused budget is not savings. Budget/call stops are censored and all failures remain.'}
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    lines=['# Sibling-search Library diagnostic','',report['claims'],'',
           '| Source | Arm | Input + all output | Submitted / feasible / optimal branches | Mean normalized incumbent improvement | Stop |',
           '|---|---|---:|---|---:|---|']
    for r in summaries:lines.append(f"| {r['case']} | {r['arm']} | {r['grossTokens']} | {r['submittedBranches']} / {r['feasibleSubmittedBranches']} / {r['optimalSubmittedBranches']} | {r['meanNormalizedImprovement']:.3f} | {r['stop']} {r['failure'] or ''} |")
    lines+=['','| Source / arm / annotation pass | Cross-branch repetitions | Supplied premise rederived | Rejected labels | Failed annotation calls |','|---|---:|---:|---:|---:|']
    for r in summaries:
        for a in r['annotation']:lines.append(f"| {r['case']} / {r['arm']} / {a['pass']} | {a['crossBranchRepeats']} | {a['suppliedPremiseRederivations']} | {a['rejectedLabels']} | {a['failedCalls']} |")
    lines+=['',f"Solver known tokens: {report['solverKnownTokens']}; annotation known tokens: {report['annotationKnownTokens']}. Unknown usage solver/annotation calls: {report['solverUnknownUsageCalls']} / {report['annotationUnknownUsageCalls']}.",
            '', 'All arms fork sibling histories from the same root and receive identical initial feasible incumbents and branch constraints. At each branch entry, Fact receives native conclusions and Scheme receives the same conclusions plus named supports from the same public Python binding. Baseline has neither. Only the common submission tool is exposed; no anti-repetition instruction is supplied. Incomplete thinking is a retained censored failure and is never salvaged by non-thinking finalization. A completed plain response may use structured finalization only within the same total budget. The independent exhaustive grader is never given to the solver. A stale handle never becomes a verified tool conclusion.',
            '', 'The producer is a locally committed clean checkout. Native build, formal checks and source identities are explicit in plan/receipts; this does not qualify another machine or remote CI. raw.tar.gz retains every request, thinking, response, tool packet, failure and annotation.']
    (output/'report.md').write_text('\n'.join(lines)+'\n')
    doc=s.ROOT/'.cache/ascent/research-reports/agent-inference/fact-reuse-results'/plan.get('artifactDirectory','sibling-search');doc.mkdir(parents=True,exist_ok=False)
    for name in ['report.json','report.md','ledger.json','annotation-ledger.json']:shutil.copy2(output/name,doc/name)
    for name in ['plan.json','plan.sha256','qualification.json','pyo3-runtime-receipt.json','native-build-receipt.json']:shutil.copy2(directory/name,doc/name)
    with tarfile.open(doc/'raw.tar.gz','w:gz') as archive:
        archive.add(directory,arcname='frozen');archive.add(output,arcname='run')
    (doc/'integrity.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in doc.iterdir() if p.is_file()},indent=2)+'\n')
    print('BRANCH_REPORT_OK',doc,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['prepare','live','shared-freeze','shared-live','shared-check','shared-committed-check','shared-label','shared-report','branch-freeze','branch-output-qualify','branch-import-output-qualification','branch-live','branch-semantic-label','branch-report']);p.add_argument('source',type=Path);p.add_argument('output',type=Path)
    a=p.parse_args()
    if a.mode.startswith(('shared-','branch-')): globals()[a.mode.replace('-','_')](a.source,a.output)
    else: prepare(a.source,a.output) if a.mode=='prepare' else live(a.source,a.output)
