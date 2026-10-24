# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Frozen multi-hop movie experiment; Scheme owns every relational operation."""
import argparse
import importlib.util
import copy
import hashlib
import json
from pathlib import Path
import shutil
import time

from ascent import Engine
from .movie_study import provider_key, MAX_OUTPUT_TOKENS
from .model_study import provider, response_outcome
from .query_contract import output_format,compact_request
from agentic_ai_lab_runtime.reasoning import rows_equal

ROOT = Path.cwd().resolve()
FIXTURE = ROOT/'t/qualification/fixtures/complex-movie/source.json'
TYPES = {'cast':['Film','Actor'], 'directed':['Film','Director'],
         'citizen':['Director','Country'], 'anchor':['Actor'],
         'eligible':['Country','Film','Director','Actor'],
         'coactor':['Actor','Film','Actor'], 'answer':['Actor']}


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True).encode()


def identity(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def var(name): return {'var':name}
def const(value): return {'const':value}
def atom(name, *terms, negative=False):
    result = {'relation':name, 'terms':list(terms)}
    if negative: result['not'] = True
    return result
def rule(head, *body): return {'head':[head], 'body':list(body)}


def declaration(name, types, source, rows, domains):
    return {'name':name, 'source':source, 'rows':rows,
            'columns':[{'kind':'symbol','domain':domains[t]} for t in types]}


def program(source, contract, views=None):
    """Frame model rules with trusted finite domains and source authority."""
    if set(contract) != {'relations','rules'}: raise ValueError('contract shape')
    names = {'cast','directed','citizen','anchor','answer','eligible','coactor','blocked','omitted_film'}
    extra = []
    for relation in contract['relations']:
        if set(relation) != {'name','types'} or relation['name'] in names:
            raise ValueError('derived declaration collision')
        names.add(relation['name'])
        extra.append(declaration(relation['name'],relation['types'],False,[],source['domains']))
    allowed_heads = {'answer'} | {r['name'] for r in contract['relations']}
    if views is None: allowed_heads |= {'eligible','coactor'}
    for index,r in enumerate(contract['rules']):
        if not isinstance(r.get('head'),list):
            raise ValueError(f'rules[{index}].head must be an array of atoms')
        if any(a['relation'] not in allowed_heads for a in r['head']):
            raise ValueError('model rule changes source authority')
    declarations = [declaration(n,TYPES[n],True,rows,source['domains']) for n,rows in source['rows'].items()]
    for name in ('eligible','coactor'):
        declarations.append(declaration(name,TYPES[name],views is not None,
                                        [] if views is None else views[name],source['domains']))
    declarations.append(declaration('answer',TYPES['answer'],False,[],source['domains']))
    return {'relations':declarations+extra,'rules':contract['rules'],'queries':['answer']}


def view_contract():
    f,d,c,a,g,x = (var(n) for n in ('f','d','c','a','g','x'))
    return {'relations':[], 'rules':[
        rule(atom('eligible',c,f,d,a),atom('cast',f,a),atom('directed',f,d),atom('citizen',d,c)),
        rule(atom('coactor',x,g,a),atom('anchor',x),atom('cast',g,x),atom('cast',g,a))]}


def execute(engine, source, contract, views=None):
    with engine.open(program(source,contract,views)) as session:
        result = session.run()
        if not result['complete']: raise RuntimeError('Scheme query incomplete')
        return result['relations']['answer']


def materialize(engine, source):
    p = program(source,view_contract()); p['queries']=['eligible','coactor']
    with engine.open(p) as session:
        result=session.run()
        if not result['complete']: raise RuntimeError('Scheme views incomplete')
        # Verify retained completed evaluation, without recomputing answers.
        retained=session.run()
        if retained['relations'] != result['relations']: raise RuntimeError('retained view differs')
        return result['relations']


def gold(case, reuse=False):
    f,d,a,g,e = (var(n) for n in ('f','d','a','g','e'))
    left = [atom('eligible',const(case['country']),f,d,a),
            atom('omitted_film',f,negative=True)]
    right = [atom('coactor',const(case['anchor']),g,a)]
    if case.get('rightCountry'):
        right.append(atom('eligible',const(case['rightCountry']),g,e,a))
    blocked = atom('blocked',a,negative=True)
    if case['scope'] in ('left','both'): left.append(blocked)
    if case['scope'] == 'both': right.append(blocked)
    rules = [] if reuse else view_contract()['rules']
    rules += [rule(atom('left',a),*left), rule(atom('right',a),*right)]
    if case['combine']=='all': rules.append(rule(atom('answer',a),atom('left',a),atom('right',a)))
    else: rules += [rule(atom('answer',a),atom(branch,a)) for branch in ('left','right')]
    return {'relations':[{'name':n,'types':['Actor']} for n in ('left','right')],'rules':rules}


def source_for(source, case):
    value=copy.deepcopy(source)
    if case['withdrawal']:
        value['rows']['cast']=[r for r in value['rows']['cast'] if r != case['withdrawal']]
    return value


def case_program(engine, source, case, contract, views=None):
    # Question bindings are sources; their types remain declared and checked.
    p=program(source,contract,views)
    p['relations'] += [declaration('omitted_film',['Film'],True,[[case['omittedFilm']]],source['domains']),
                       declaration('blocked',['Actor'],True,[[case['blocked']]],source['domains'])]
    with engine.open(p) as session:
        result=session.run()
        if not result['complete']: raise RuntimeError('Scheme query incomplete')
        return result['relations']['answer']


def cases(stratum='shared-actor'):
    values=[]
    for combine,scope in [('all','left'),('any','left'),('all','none'),('any','both'),('all','both'),('any','none')]:
        values.append({'name':f'{combine}-{scope}', 'country':'Q145','anchor':'Q38111',
                       'omittedFilm':'Q25188','blocked':'Q38111','combine':combine,
                       'scope':scope,'withdrawal':None})
    for name,row in [('withdraw-hardy',['Q18002795','Q208026']),('withdraw-inception-caine',['Q25188','Q123351'])]:
        values.append({**values[0],'name':name,'withdrawal':row})
    for c in values:
        op='同时满足 L 和 R' if c['combine']=='all' else '满足 L 或 R'
        exclusion={'left':'只在 L 排除莱昂纳多','both':'在 L 和 R 都排除莱昂纳多','none':'不排除任何演员'}[c['scope']]
        c['question']=(f'仅使用冻结事实。L：演员出演某部电影，该电影导演具有英国国籍，且电影不是《盗梦空间》。'
                       f'R：演员出演某部电影，该电影的演员列表也包含莱昂纳多。演员可以就是莱昂纳多本人。'
                       f'找出{op}的演员；{exclusion}。L 与 R 可以由不同电影支持，必须连接同一演员。'
                       f'按演员 QID 去重。事实缺失只表示在本有限提取中不存在。')
        if c['withdrawal']: c['question']+=f'本题使用撤回 cast{c["withdrawal"]} 后的快照。'
    if stratum=='shared-actor':return values
    if stratum!='country-qualified':raise ValueError('unknown query stratum')
    union={**values[1],'name':'country-scoped-union','blocked':'Q208026','rightCountry':'Q96'}
    join={**union,'name':'country-qualified-join','combine':'all','scope':'none'}
    withdrawal={**union,'name':'country-support-withdrawal','withdrawal':['Q18002795','Q208026']}
    result=[union,join,withdrawal]
    for c in result:
        c['question']=('仅使用冻结事实。L：演员出演某部电影，电影导演具有英国国籍(Q145)，'
            '电影不是《盗梦空间》(Q25188)。R：演员与莱昂纳多(Q38111)出演同一部电影，'
            '且这部共同出演电影的导演具有墨西哥国籍(Q96)。L 和 R 可以使用不同电影，'
            '但必须连接同一演员；R 的共同出演与导演国籍必须由同一部电影支持。'
            +('找出满足 L 或 R 的演员，只在 L 排除 Tom Hardy(Q208026)，R 不排除他。' if c['combine']=='any' else
              '找出同时满足 L 和 R 的演员，不排除任何演员。')+
            '演员可以就是莱昂纳多本人。按演员 QID 去重，事实缺失只表示在本有限提取中不存在。')
        if c['withdrawal']:c['question']+='本题已撤回 cast(荒野猎人 Q18002795,Tom Hardy Q208026)，其余事实保持不变。'
    return result


def request(source,case,arm,views=None,compiler_context='facts'):
    if compiler_context not in ('facts','intent'):raise ValueError('unknown compiler context')
    public={'question':case['question'],'bindings':{k:case[k] for k in ('country','anchor','omittedFilm','blocked')},
            'domains':source['domains'],'facts':source['rows'],
            'schema':{**TYPES,'omitted_film':['Film'],'blocked':['Actor']}}
    if case.get('rightCountry'):public['bindings']['rightCountry']=case['rightCountry']
    if arm=='direct':
        instruction='Return only a JSON array of actor QIDs answering the question. Use no outside facts.'
    else:
        if views is not None: public['materializedViews']=views
        instruction=('Compile the question to a finite relational program, not its answer. Return JSON with exactly '
            'relations and rules. relations declares only additional derived relations as {name,types}, with types '
            'from Film,Actor,Director,Country. answer(Actor) is already declared. Source relations cast(Film,Actor), '
            'directed(Film,Director), citizen(Director,Country), anchor(Actor), omitted_film(Film), blocked(Actor) '
            'are trusted. eligible(Country,Film,Director,Actor) and coactor(Actor,Film,Actor) are already declared: '
            +('they contain supplied materialized rows; do not define their rule heads. ' if views is not None else
              'they are empty derived relations; define them if used. ')+
            'Each rule is {head:[atom],body:[atoms]}. An atom is {relation,terms:[{var:"x"} or {const:"QID"}],'
            'not:true optionally}. Negation must be stratified and all variables grounded by positive atoms. '
            'Multiple rules for one head implement union; shared variables implement joins. Never put source '
            'relations in heads. ReasoningRuntime queries answer. No Python, Scheme, prose or markdown.')
    result={'model':'deepseek-flash','input':[{'role':'user','content':instruction+'\n'+encoded(public).decode()}],
            'reasoning':{'effort':'high'},'max_output_tokens':MAX_OUTPUT_TOKENS,'stream':True,'store':False}
    if arm!='direct':result['text']={'format':output_format()}
    if arm!='direct' and compiler_context=='intent':result=compact_request(result,identity(source))
    return result


def prepare(directory, library, stratum='shared-actor',compiler_context='facts'):
    source=json.loads(FIXTURE.read_text()); directory.mkdir(parents=True,exist_ok=False)
    shutil.copyfile(library,directory/library.name)
    plan={'schema':'ascent.complex-movie-plan.v1','purpose':'multi-hop feasibility pilot, not powered main evaluation',
          'maxCalls':len(cases(stratum))*3,'stratum':stratum,'retries':0,'maxOutputTokens':MAX_OUTPUT_TOKENS,'arms':['direct','execute','reuse'],
          'source':source,'sourceSha256':identity(source),'driverSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'library':library.name,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'cases':cases(stratum),
          'contractSchemaSha256':identity(output_format()),
          'compilerContext':compiler_context,
          'producerHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in
              [Path(__file__),Path(__file__).with_name('query_contract.py'),Path(__file__).with_name('model_study.py'),
               Path(__file__).with_name('movie_study.py'),ROOT/'rust/ascent-python/src/api/exports.rs']},
          'primaryMetrics':['exact answer sets','source withdrawal freshness','total provider usage'],
          'reuseBoundary':'Whole-source identity; exact materialized typed views; conservative full invalidation on change',
          'order':[],'gold':{},'offline':[]}
    with Engine() as engine:
        cache={}
        for i,case in enumerate(plan['cases']):
            s=source_for(source,case);key=identity(s)
            fresh=materialize(engine,s);hit=key in cache
            views=cache.setdefault(key,fresh)
            if views!=fresh: raise RuntimeError('view cache stale')
            expected=case_program(engine,s,case,gold(case))
            reused=case_program(engine,s,case,gold(case,True),views)
            if not rows_equal(expected, reused):
                raise RuntimeError('materialized substitution differs')
            plan['gold'][case['name']]=expected
            plan['offline'].append({'case':case['name'],'answers':len(expected),'viewCacheHit':hit,
                                    'freshMatchesReused':True,'viewRows':{n:len(r) for n,r in views.items()}})
            arms=plan['arms'][i%3:]+plan['arms'][:i%3]
            for arm in arms:
                req=request(s,case,arm,views if arm=='reuse' else None,compiler_context)
                name=f'{case["name"]}.{arm}.request.json'; data=encoded(req)
                (directory/name).write_bytes(data)
                plan['order'].append({'case':case['name'],'arm':arm,'request':name,
                                      'sha256':hashlib.sha256(data).hexdigest()})
            print('COMPLEX-OFFLINE',case['name'],'answers',len(expected),'cache-hit',hit,flush=True)
    # Conservative byte-per-token estimate plus full output cap; excludes future trials.
    plan['conservativeScheduledUpperUsd']=sum((len((directory/x['request']).read_bytes())+1024)*.3+
                                            MAX_OUTPUT_TOKENS*1.2 for x in plan['order'])/1e6
    (directory/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
    print('COMPLEX-PREPARED calls',plan['maxCalls'],'upper-usd',plan['conservativeScheduledUpperUsd'],flush=True)


def live(directory, output):
    plan=json.loads((directory/'plan.json').read_text())
    if identity(plan['source'])!=plan['sourceSha256'] or identity(json.loads(FIXTURE.read_text()))!=plan['sourceSha256']:
        raise ValueError('frozen source changed')
    if plan['driverSha256']!=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(): raise ValueError('driver changed')
    if plan.get('contractSchemaSha256')!=identity(output_format()):raise ValueError('contract schema changed')
    for name,sha in plan.get('producerHashes',{}).items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=sha:raise ValueError(f'producer changed: {name}')
    lib=directory/plan['library']
    if plan['librarySha256']!=hashlib.sha256(lib.read_bytes()).hexdigest(): raise ValueError('library changed')
    if len(plan['order'])!=plan['maxCalls'] or plan['maxCalls'] not in (9,24) or plan['conservativeScheduledUpperUsd']>5:
        raise ValueError('pilot bounds')
    for item in plan['order']:
        if item['sha256']!=hashlib.sha256((directory/item['request']).read_bytes()).hexdigest(): raise ValueError('request changed')
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    (directory/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.complex-movie-result.v1','planSha256':hashlib.sha256((directory/'plan.json').read_bytes()).hexdigest(),
             'purpose':plan['purpose'],'records':[],'savingsConclusion':None}
    cache={};startup=time.monotonic()
    with Engine() as engine:
        receipt['engineInitializationSeconds']=time.monotonic()-startup
        for i,item in enumerate(plan['order']):
            case=next(c for c in plan['cases'] if c['name']==item['case']);s=source_for(plan['source'],case)
            d=output/f'{i:02d}';d.mkdir();req=json.loads((directory/item['request']).read_text())
            views=None;hit=False;setup=time.monotonic()
            if item['arm']=='reuse':
                sid=identity(s);hit=sid in cache
                if not hit: cache[sid]=materialize(engine,s)
                views=cache[sid]
                frozen=json.loads(req['input'][0]['content'].split('\n',1)[1])['materializedViews']
                if not all(rows_equal(rows, frozen[name])
                           for name,rows in views.items()):
                    raise ValueError('runtime views differ from frozen context')
            setup_seconds=time.monotonic()-setup
            print('COMPLEX-CALL',i+1,'/',plan['maxCalls'],item['case'],item['arm'],flush=True)
            raw,meta=provider(req,key,d/'response.json');(d/'raw.txt').write_text(raw)
            record={**item,'outcome':response_outcome(meta),'usage':(meta['terminal'] or {}).get('usage'),
                    'providerSeconds':meta['providerSeconds'],'correct':False,'sourceIdentity':identity(s),
                    'viewSetupSeconds':setup_seconds,'viewCacheHit':hit}
            if record['outcome']=='completed_ungraded':
                started=time.monotonic()
                try:
                    candidate=json.loads(raw)
                    if item['arm']=='direct':
                        if not isinstance(candidate,list) or not all(isinstance(x,str) and x in s['domains']['Actor'] for x in candidate):
                            raise ValueError('answer domain')
                        answer=[[x] for x in candidate]
                    else: answer=case_program(engine,s,case,candidate,views)
                    record['correct']=rows_equal(answer, plan['gold'][case['name']])
                    record['answer']=answer;record['viewCacheHit']=hit
                    record['outcome']=response_outcome(meta,record['correct'])
                except Exception as error:
                    record['outcome']='admission_or_execution_failure';record['failure']=str(error)[:2048]
                record['schemeAndAdmissionSeconds']=time.monotonic()-started
            receipt['records'].append(record)
            (output/'result.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
            print('\nCOMPLEX-RESULT',record['outcome'],flush=True)
            if meta['error'] or (meta['terminal'] or {}).get('status')=='failed':break


def qualify(corpus, library, output):
    extension = Path(importlib.util.find_spec('ascent._core').origin).resolve()
    if library.resolve() != extension:
        raise ValueError('qualification requires the installed PyO3 extension')
    observations=json.loads(corpus.read_text());checked=0
    if len(observations)!=3072: raise ValueError('finite corpus bound')
    def contract(reuse):
        result={'relations':[], 'rules':[] if reuse else view_contract()['rules']}
        for mode in range(6):
            c={'combine':'all' if mode//3==0 else 'any','scope':['left','both','none'][mode%3],
               'country':'country','anchor':'a0'}
            part=gold(c,True)
            names={n:f'{n}{mode}' for n in ('left','right','answer')}
            result['relations'] += [{'name':names[n],'types':['Actor']} for n in names]
            for r in part['rules']:
                for a in r['head']+r['body']: a['relation']=names.get(a['relation'],a['relation'])
                result['rules'].append(r)
        return result
    def make_source(sid):
        bits=sid%256
        return {'domains':{'Film':['f0','f1'],'Actor':['a0','a1','a2'],
                           'Director':['d0','d1'],'Country':['country']},
                'rows':{'cast':[[f'f{f}',f'a{a}'] for f in range(2) for a in range(3)
                                if bits&(1<<(f*3+a)) and not(sid//256==1 and f==1 and a==1)],
                        'directed':[['f0','d0'],['f1','d1']],
                        'citizen':[[f'd{f}','country'] for f in range(2) if bits&(1<<(6+f))],
                        'anchor':[['a0']], 'omitted_film':[['f0']], 'blocked':[['a0']]}}
    def combined(source,reuse,views=None):
        types={**TYPES,'omitted_film':['Film'],'blocked':['Actor']}
        # program() intentionally frames question sources separately elsewhere.
        base=copy.deepcopy(source);base['rows']={k:v for k,v in source['rows'].items() if k not in ('omitted_film','blocked')}
        p=program(base,contract(reuse),views)
        p['relations'] += [declaration(n,types[n],True,source['rows'][n],source['domains']) for n in ('omitted_film','blocked')]
        p['queries']=['eligible','coactor']+[f'answer{m}' for m in range(6)]
        return p
    started=time.monotonic()
    with Engine() as engine:
        first=make_source(0)
        with engine.open(combined(first,False)) as fresh, engine.open(combined(first,True,{'eligible':[],'coactor':[]})) as reused:
            for sid in range(512):
                source=make_source(sid)
                if sid: fresh.replace(source['rows'])
                result=fresh.run()
                if not result['complete']: raise RuntimeError('fresh incomplete')
                views={n:result['relations'][n] for n in ('eligible','coactor')}
                if sid: reused.replace({**source['rows'],**views})
                retained=reused.run()
                if not retained['complete'] or not all(rows_equal(rows, retained['relations'][name]) for name,rows in result['relations'].items()):
                    raise RuntimeError(f'retained source/view replacement differs {sid}')
                for mode in range(6):
                    n=sid*6+mode;answer=result['relations'][f'answer{mode}']
                    actual=[n,sum(1<<(int(r[1][-1])*3+int(r[3][-1])) for r in views['eligible']),
                            sum(1<<(int(r[1][-1])*3+int(r[2][-1])) for r in views['coactor']),
                            sum(1<<int(r[0][-1]) for r in answer)]
                    if actual!=observations[n]: raise RuntimeError(f'Scheme/Quint mismatch {n}: {actual}')
                    checked+=1
                if sid%8==7: print('COMPLEX-CORRESPONDENCE',checked,'/3072',flush=True)
        source=make_source(255);views=materialize(engine,{**source,'rows':{n:r for n,r in source['rows'].items() if n not in ('omitted_film','blocked')}})
        c={'country':'country','anchor':'a0','omittedFilm':'f0','blocked':'a0','combine':'any','scope':'left'}
        clean={**source,'rows':{n:r for n,r in source['rows'].items() if n not in ('omitted_film','blocked')}}
        correct=case_program(engine,clean,c,gold(c,True),views)
        wrong=case_program(engine,clean,{**c,'scope':'both'},gold({**c,'scope':'both'},True),views)
        if rows_equal(wrong, correct):
            raise RuntimeError('global exclusion mutation survived')
        join={**c,'combine':'all'}
        correct=case_program(engine,clean,join,gold(join,True),views)
        if rows_equal(case_program(engine,clean,c,gold(c,True),views), correct):
            raise RuntimeError('union mutation survived')
        updated=make_source(511);updated['rows']={n:r for n,r in updated['rows'].items() if n not in ('omitted_film','blocked')}
        correct=case_program(engine,updated,join,gold(join))
        stale=case_program(engine,updated,join,gold(join,True),views)
        if rows_equal(stale, correct):
            raise RuntimeError('stale materialized views survived')
        print('COMPLEX-FAULT-CONTROLS global-exclusion union-for-join stale-views detected=3',flush=True)
    output.write_text(json.dumps({'schema':'ascent.materialized-movie-correspondence.v1',
                                 'observations':checked,'allEqual':True,'retainedSessions':2,
                                 'sourceSnapshots':512,'faultControlsDetected':['global-exclusion','union-for-join','stale-views'],
                                 'seconds':time.monotonic()-started,
                                 'corpusSha256':hashlib.sha256(corpus.read_bytes()).hexdigest(),
                                 'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()})+'\n')


def main():
    p=argparse.ArgumentParser();sub=p.add_subparsers(dest='mode',required=True)
    s=sub.add_parser('prepare');s.add_argument('directory',type=Path);s.add_argument('library',type=Path)
    s.add_argument('--stratum',choices=('shared-actor','country-qualified'),default='shared-actor')
    s.add_argument('--compiler-context',choices=('facts','intent'),default='facts')
    s=sub.add_parser('live');s.add_argument('directory',type=Path);s.add_argument('output',type=Path)
    s=sub.add_parser('qualify');s.add_argument('corpus',type=Path);s.add_argument('library',type=Path);s.add_argument('output',type=Path)
    args=p.parse_args()
    if args.mode=='prepare':prepare(args.directory.resolve(),args.library.resolve(),args.stratum,args.compiler_context)
    elif args.mode=='live':live(args.directory.resolve(),args.output.resolve())
    else:qualify(args.corpus.resolve(),args.library.resolve(),args.output.resolve())


if __name__=='__main__':main()
