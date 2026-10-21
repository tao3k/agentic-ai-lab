# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Frozen intent compilation versus retained Scheme execution; no gold in prompts."""
import argparse
import copy
import hashlib
import json
import shutil
import time
from pathlib import Path

from ascent import Engine
from .complex_movie_study import atom, rule, var, declaration, identity, ROOT
from .query_contract import output_format
from .movie_study import provider_key, MAX_OUTPUT_TOKENS
from .model_study import provider, response_outcome

SCHEMA = {'cast':['Film','Actor'], 'directed':['Film','Director'],
          'citizen':['Director','Country'], 'mentor':['Actor','Actor'],
          'actor_domain':['Actor'], 'banned_film':['Film'],
          'selected_country':['Country'], 'target':['Actor']}
STRUCTURES = ('mentor-chain', 'witness-local-exclusion', 'anti-existential', 'recursive-mentor')


def workload(index):
    """Independent synthetic entities and four structures withheld from movie pilot."""
    prefix=f'holdout{index}_'
    actors=[prefix+f'actor{i}' for i in range(12)]
    films=[prefix+f'film{i}' for i in range(6)]
    directors=[prefix+f'director{i}' for i in range(3)]
    countries=[prefix+f'country{i}' for i in range(2)]
    rows={'cast':[[films[f],actors[a]] for f,a in
                 [(0,0),(0,1),(0,2),(1,1),(1,3),(2,2),(2,4),(3,5),(3,6),
                  (4,6),(4,7),(5,8),(5,9)]],
          'directed':[[f,directors[i%3]] for i,f in enumerate(films)],
          'citizen':[[directors[0],countries[0]],[directors[1],countries[1]],
                     [directors[2],countries[0]]],
          'mentor':[[actors[a],actors[b]] for a,b in
                    [(10,11),(11,0),(9,1),(8,9),(7,8),(6,7),(5,6),(4,5),(3,4),(2,3),(1,2),(0,1)]],
          'actor_domain':[[a] for a in actors], 'banned_film':[[films[0]]],
          'selected_country':[[countries[0]]], 'target':[[actors[0]]]}
    if index==3:
        rows['mentor'].remove([actors[9],actors[1]])
        rows['mentor'].append([actors[9],actors[10]])
    source={'domains':dict(Film=films,Actor=actors,Director=directors,Country=countries),'rows':rows}
    structure=STRUCTURES[index]
    questions={
      'mentor-chain':'Return actors x with a directed mentor edge x->y and y->z, where z acts in a film whose director has the selected_country. The two mentor edges must share y; cast, directed and citizen must share the same film and director. Actors may repeat along the path; do not require x itself to act.',
      'witness-local-exclusion':'Return actors with at least one film directed by a director with selected_country, with that supporting film not in banned_film. Exclude individual supporting films before projecting actor: acting in a banned film must not exclude an actor who also has another qualifying, unbanned film.',
      'anti-existential':'Return actors in actor_domain with at least one film whose director has selected_country AND with no appearance in any banned_film. The second condition excludes the entire actor if ANY banned-film appearance exists, even if a different film qualifies.',
      'recursive-mentor':'Return actors that can reach an actor in target through ONE OR MORE directed mentor edges. Include any path length, including cycles; zero-length paths alone do not qualify. An actor in target qualifies only if it also has a positive-length path to target.'}
    return {'name':structure,'question':questions[structure]+' Use only the supplied finite relations. Return unique actor identifiers.',
            'source':source,'withdrawal':{'relation':'mentor' if index in (0,3) else 'cast',
              'row':[actors[11],actors[0]] if index==0 else
                    [actors[0],actors[1]] if index==3 else
                    [films[2],actors[2]] if index==1 else [films[0],actors[2]]}}


def updated(case):
    source=copy.deepcopy(case['source']);change=case['withdrawal']
    source['rows'][change['relation']].remove(change['row'])
    return source


def expected(case, source):
    """Independent finite set oracle, never imported into model-facing request."""
    rows=source['rows'];cast=set(map(tuple,rows['cast']));edges=set(map(tuple,rows['mentor']))
    selected={r[0] for r in rows['selected_country']};banned={r[0] for r in rows['banned_film']}
    qualifying={f for f,d in rows['directed'] for dd,c in rows['citizen'] if d==dd and c in selected}
    eligible={a for f,a in cast if f in qualifying}
    name=case['name']
    if name=='mentor-chain':answer={x for x,y in edges for yy,z in edges if y==yy and z in eligible}
    elif name=='witness-local-exclusion':answer={a for f,a in cast if f in qualifying and f not in banned}
    elif name=='anti-existential':answer=eligible-{a for f,a in cast if f in banned}
    else:
        paths=set(edges)
        while True:
            more=paths|{(x,z) for x,y in paths for yy,z in edges if y==yy}
            if more==paths:break
            paths=more
        target={r[0] for r in rows['target']};answer={x for x,y in paths if y in target}
    return [[a] for a in sorted(answer)]


def oracle_contract(case):
    a,b,c,f,d,k=(var(n) for n in ('a','b','c','f','d','k'))
    eligible=[atom('cast',f,a),atom('directed',f,d),atom('citizen',d,k),atom('selected_country',k)]
    name=case['name'];relations=[]
    if name=='mentor-chain':
        eligible=[atom('mentor',a,b),atom('mentor',b,c),atom('cast',f,c),*eligible[1:]]
        rules=[rule(atom('answer',a),*eligible)]
    elif name=='witness-local-exclusion':rules=[rule(atom('answer',a),*eligible,atom('banned_film',f,negative=True))]
    elif name=='anti-existential':
        relations=[{'name':'excluded','types':['Actor']}]
        rules=[rule(atom('excluded',a),atom('cast',f,a),atom('banned_film',f)),
               rule(atom('answer',a),*eligible,atom('excluded',a,negative=True))]
    else:
        relations=[{'name':'reachable','types':['Actor','Actor']}]
        rules=[rule(atom('reachable',a,b),atom('mentor',a,b)),
               rule(atom('reachable',a,c),atom('reachable',a,b),atom('mentor',b,c)),
               rule(atom('answer',a),atom('reachable',a,b),atom('target',b))]
    return {'relations':relations,'rules':rules}


def program(source, contract):
    if set(contract)!={'relations','rules'}:raise ValueError('contract shape')
    names=set(SCHEMA)|{'answer'};extra=[]
    for r in contract['relations']:
        if set(r)!={'name','types'} or r['name'] in names:raise ValueError('source/declaration collision')
        names.add(r['name']);extra.append(declaration(r['name'],r['types'],False,[],source['domains']))
    allowed={r['name'] for r in extra}|{'answer'}
    for r in contract['rules']:
        if not isinstance(r.get('head'),list) or not r['head']:raise ValueError('head must be nonempty atom array')
        if any(a['relation'] not in allowed for a in r['head']):raise ValueError('source authority')
    sources=[declaration(n,SCHEMA[n],True,rows,source['domains']) for n,rows in source['rows'].items()]
    return {'relations':sources+[declaration('answer',['Actor'],False,[],source['domains'])]+extra,
            'rules':contract['rules'],'queries':['answer']}


def request(case, source, arm):
    public={'question':case['question'],'schema':SCHEMA,
            'relationMeaning':{'cast':'film appearance by actor','directed':'film director',
              'citizen':'director nationality','mentor':'directed actor-to-actor mentoring edge',
              'actor_domain':'all actors','banned_film':'excluded supporting films',
              'selected_country':'selected nationality','target':'target actor set'}}
    if arm=='direct':
        public.update(facts=source['rows'],domains=source['domains'])
        instruction='Return only a JSON array of actor identifiers, using no outside facts.'
    else:
        instruction=('Compile question intent, not answer values. Return {relations,rules}. Sources in schema are trusted; '
          'never define source heads. answer(Actor) is already declared. Additional derived relations are {name,types}. '
          'Every rule has head:[{relation,terms}] and body:[{relation,terms,not:true optionally}]. '
          'Terms are {var:name} or {const:value}. Shared variables join; multiple rules union. '
          'Negation must be stratified, with all variables bound by positive atoms. '
          'Recursion computes the least fixed point. Data and entity identifiers stay in Scheme. '
          'Do not hardcode actors or enumerate answers. Use source relations for bindings.')
    req={'model':'deepseek-flash','input':[{'role':'user','content':instruction+'\n'+json.dumps(public,sort_keys=True)}],
         'reasoning':{'effort':'high'},'max_output_tokens':MAX_OUTPUT_TOKENS,'stream':True,'store':False}
    if arm!='direct':req['text']={'format':output_format()}
    return req


def price(usage):
    if not usage:raise ValueError('missing usage')
    cached=usage.get('input_tokens_details',{}).get('cached_tokens',0)
    return ((usage['input_tokens']-cached)*.3+cached*.006+usage['output_tokens']*1.2)/1e6


def completed_contract(contract, outcome):
    if outcome!='completed_ungraded':raise ValueError(f'provider contract not completed: {outcome}')
    if not isinstance(contract,dict):raise ValueError('completed provider response is not a contract object')
    return contract


def prepare(directory, library):
    directory.mkdir(parents=True,exist_ok=False)
    frozen_library=directory/library.name
    shutil.copy2(library,frozen_library)
    library=frozen_library
    cases=[workload(i) for i in range(4)]
    with Engine() as engine:
        for case in cases:
            for phase,source in [('cold',case['source']),('updated',updated(case))]:
                with engine.open(program(source,oracle_contract(case))) as session:
                    result=session.run()
                    if not result['complete'] or sorted(result['relations']['answer'])!=expected(case,source):
                        raise ValueError('independent gold disagreement')
                print('HOLDOUT-ORACLE',case['name'],phase,len(expected(case,source)),flush=True)
    plan={'schema':'ascent.inference-reuse-plan.v1','cases':cases,'repetitions':2,'maxProviderCalls':32,
          'maxOutputTokens':MAX_OUTPUT_TOKENS,'upperPeakEstimateUsd':3.0,
          'scope':'Four synthetic structural holdouts, independently named entities; two repeated cold controls. Not a real-world KGQA benchmark.',
          'repeatBaseline':'Direct model is called again; also report identical-request answer-cache control with zero repeat calls.',
          'reuseKey':'Exact question, schema, contract and engine identity; no natural-language similarity matching.',
          'sourceUpdate':'Retain rules, replace trusted source rows in Scheme; invalidate completed answer. No model call.',
          'recovery':'No repair or retry in primary evaluation. Failed contracts remain failures in all retained phases.',
          'reflectionInputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
             for p in [ROOT/'.cache/ascent/archived-runs/docs/research/agent-inference/movie-reflection-result.json',ROOT/'.cache/ascent/archived-runs/docs/research/agent-inference/complex-movie-result.json']},
          'reflectionDecisions':['Use structured head arrays.', 'Union and join explicit in ABI.',
             'Keep existential witness exclusion distinct from actor-wide exclusion.',
             'Compile intent without fact enumeration.', 'Retain Scheme session; do not call model on exact repeat.',
             'Withdraw sources and check against independent oracle; never return stale answer.'],
          'producerHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [Path(__file__),Path(__file__).with_name('query_contract.py'),Path(__file__).with_name('model_study.py'),
                      Path(__file__).with_name('movie_study.py'),ROOT/'rust/ascent-python/src/api/exports.rs']},
          'library':library.name,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'priceSource':'https://api-docs.deepseek.com/quick_start/pricing/'}
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')


def live(directory,library,output):
    plan_path=directory/'plan.json';plan=json.loads(plan_path.read_text())
    if 'library' in plan:library=directory/plan['library']
    if plan['maxProviderCalls']!=32 or plan['repetitions']!=2:raise ValueError('plan bounds')
    for name,sha in {**plan['producerHashes'],**plan['reflectionInputs']}.items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=sha:raise ValueError('producer/reflection changed')
    if hashlib.sha256(library.read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine changed')
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    (directory/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.inference-reuse-result.v1','planSha256':hashlib.sha256(plan_path.read_bytes()).hexdigest(),
             'providerCalls':0,'peakEstimateUsd':0,'records':[],'scope':plan['scope']}
    def save(): (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def call(case,source,arm,rep,phase):
        req=request(case,source,arm);name=f'{case["name"]}-{rep}-{arm}-{phase}'
        (output/(name+'.request.json')).write_text(json.dumps(req,indent=2)+'\n')
        print('HOLDOUT-MODEL',receipt['providerCalls']+1,'/32',name,flush=True)
        raw,meta=provider(req,key,output/(name+'.response.json'))
        (output/(name+'.raw.txt')).write_text(raw)
        usage=(meta.get('terminal') or {}).get('usage')
        rec={'case':case['name'],'repetition':rep,'phase':phase,'arm':arm,'providerCalls':1,
             'requestSha256':identity(req),'sourceIdentity':identity(source),'outcome':response_outcome(meta),
             'usage':usage,'providerSeconds':meta['providerSeconds'],'correct':False,
             'peakEstimateUsd':price(usage) if usage else None}
        rec['providerOutcome']=rec['outcome']
        rec['incompleteDetails']=(meta.get('terminal') or {}).get('incomplete_details')
        receipt['providerCalls']+=1;receipt['peakEstimateUsd']+=rec['peakEstimateUsd'] or 0
        receipt['records'].append(rec);save()
        if meta.get('error') or (meta.get('terminal') or {}).get('status')=='failed':
            raise RuntimeError('provider failure; partial receipt retained')
        if not usage:raise RuntimeError('missing provider usage; cost cannot be inferred')
        try:prediction=json.loads(raw) if rec['outcome']=='completed_ungraded' else None
        except ValueError:prediction=None
        return rec,prediction
    with Engine() as engine:
        for rep in range(2):
            for case in plan['cases']:
                session=None
                try:
                    for phase in ('cold','repeat','updated'):
                        source=updated(case) if phase=='updated' else case['source']
                        if phase=='cold' and rep==1:
                            candidate,contract=call(case,source,'compact',rep,phase)
                        baseline,prediction=call(case,source,'direct',rep,phase)
                        baseline['correct']=isinstance(prediction,list) and all(isinstance(a,str) for a in prediction) and sorted([[a] for a in prediction])==expected(case,source)
                        baseline['outcome']=response_outcome({'terminal':{'status':'completed'}},baseline['correct']) if baseline['outcome']=='completed_ungraded' else baseline['outcome']
                        if phase=='cold':
                            if rep==0:candidate,contract=call(case,source,'compact',rep,phase)
                        else:
                            candidate={'case':case['name'],'repetition':rep,'phase':phase,'arm':'compact',
                               'providerCalls':0,'peakEstimateUsd':0,'sourceIdentity':identity(source),'correct':False}
                            receipt['records'].append(candidate)
                        started=time.monotonic()
                        try:
                            if phase=='cold':
                                contract=completed_contract(contract,candidate['providerOutcome'])
                                session=engine.open(program(source,contract));candidate['contractSha256']=identity(contract)
                            if session is None:raise ValueError('no admitted cold contract')
                            if phase=='updated':
                                session.replace(source['rows'])
                            result=session.run(0 if phase=='repeat' else 1000000000)
                            if not result['complete']:raise ValueError('Scheme query incomplete')
                            candidate.update(answer=result['relations']['answer'],correct=sorted(result['relations']['answer'])==expected(case,source))
                            candidate['outcome']='correct' if candidate['correct'] else 'answer_mismatch'
                        except Exception as error:
                            candidate.update(outcome=candidate['providerOutcome'] if phase=='cold' and candidate['providerOutcome']!='completed_ungraded'
                                else 'admission_or_execution_failure',failure=str(error)[:2048])
                        candidate['schemeSeconds']=time.monotonic()-started
                        candidate['zeroBudgetRetained']=phase=='repeat' and candidate['outcome']!='admission_or_execution_failure'
                        save();print('HOLDOUT-RESULT',case['name'],rep,phase,baseline['outcome'],candidate['outcome'],flush=True)
                finally:
                    if session is not None:session.close()
    summary={}
    for arm in ('direct','compact'):
        for phase in ('cold','repeat','updated'):
            records=[r for r in receipt['records'] if r['arm']==arm and r['phase']==phase]
            summary[f'{arm}/{phase}']={'correct':sum(r['correct'] for r in records),'tasks':len(records),
                 'providerCalls':sum(r['providerCalls'] for r in records),
                 'peakEstimateUsd':sum(r.get('peakEstimateUsd') or 0 for r in records)}
    direct=sum(r['peakEstimateUsd'] for k,r in summary.items() if k.startswith('direct/'))
    compact=sum(r['peakEstimateUsd'] for k,r in summary.items() if k.startswith('compact/'))
    # Identical source/question baseline answer cache can skip repeats too.
    cached_direct=direct-summary['direct/repeat']['peakEstimateUsd']
    receipt.update(summary=summary,threePhaseApiReduction=1-compact/direct,
          versusExactAnswerCachedDirectApiReduction=1-compact/cached_direct,
          note='Both reductions are API estimates, not machine cost. Compare quality before admitting savings. Exact repetition alone has no advantage over a correct generic answer cache.')
    save();print('HOLDOUT-SUMMARY',json.dumps(summary),flush=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('prepare','live'))
    p.add_argument('directory',type=Path);p.add_argument('library',type=Path);p.add_argument('output',type=Path,nargs='?')
    a=p.parse_args()
    if a.mode=='prepare':prepare(a.directory.resolve(),a.library.resolve())
    elif a.output is None:p.error('live requires output')
    else:live(a.directory.resolve(),a.library.resolve(),a.output.resolve())


if __name__=='__main__':main()
