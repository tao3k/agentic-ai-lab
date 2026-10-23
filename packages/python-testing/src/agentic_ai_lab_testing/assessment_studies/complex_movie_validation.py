# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Post-pilot structural repair and source-transfer diagnostics, without paid replay."""
import argparse
import copy
import hashlib
import json
import time
from pathlib import Path
from ascent import Engine
from . import complex_movie_study as study
from .query_contract import output_format,compact_request
from .model_study import provider,response_outcome
from .movie_study import provider_key,MAX_OUTPUT_TOKENS
from agentic_ai_lab_runtime.reasoning import rows_equal


def singleton_heads(contract):
    """One syntactic projection only; no operator, constant or body changes."""
    repaired=copy.deepcopy(contract);count=0
    if not isinstance(repaired,dict) or set(repaired)!={'relations','rules'}:
        raise ValueError('contract shape')
    for rule in repaired['rules']:
        if isinstance(rule.get('head'),dict):
            rule['head']=[rule['head']];count+=1
    return repaired,count


def witnesses(engine,source,case):
    contract=study.gold(case)
    a,f,d,g,e=(study.var(n) for n in ('a','f','d','g','e'))
    left=[study.atom('answer',a),study.atom('eligible',study.const(case['country']),f,d,a),
          study.atom('omitted_film',f,negative=True)]
    right=[study.atom('answer',a),study.atom('coactor',study.const(case['anchor']),g,a)]
    right_terms=[a,g,study.const(case['anchor'])]
    right_types=['Actor','Film','Actor']
    if case.get('rightCountry'):
        right.append(study.atom('eligible',study.const(case['rightCountry']),g,e,a))
        right_terms += [e,study.const(case['rightCountry'])];right_types += ['Director','Country']
    if case['scope'] in ('left','both'):left.append(study.atom('blocked',a,negative=True))
    if case['scope']=='both':right.append(study.atom('blocked',a,negative=True))
    contract['relations'] += [{'name':'audit_left','types':['Actor','Film','Director','Country']},
                               {'name':'audit_right','types':right_types}]
    contract['rules'] += [study.rule(study.atom('audit_left',a,f,d,study.const(case['country'])),*left),
                          study.rule(study.atom('audit_right',*right_terms),*right)]
    p=study.program(source,contract)
    p['relations'] += [study.declaration('omitted_film',['Film'],True,[[case['omittedFilm']]],source['domains']),
                       study.declaration('blocked',['Actor'],True,[[case['blocked']]],source['domains'])]
    p['queries']=['answer','audit_left','audit_right']
    with engine.open(p) as session:
        result=session.run()
        if not result['complete']:raise RuntimeError('witness evaluation incomplete')
    index={}
    for claim in source['claims']:
        index.setdefault((claim['relation'],tuple(claim['row'])),[]).append(claim['statement'])
    receipt={'answers':result['relations']['answer'],'left':[],'right':[]}
    for actor,film,director,country in result['relations']['audit_left']:
        receipt['left'].append({'row':[actor,film,director,country],
            'statements':[index[('cast',(film,actor))],index[('directed',(film,director))],index[('citizen',(director,country))]]})
    for row in result['relations']['audit_right']:
        actor,film,anchor=row[:3]
        statements=[index[('cast',(film,actor))],index[('cast',(film,anchor))]]
        if len(row)==5:
            director,country=row[3:]
            statements += [index[('directed',(film,director))],index[('citizen',(director,country))]]
        receipt['right'].append({'row':row,'statements':statements})
    return receipt


def validate(preview,results,library,output):
    plan=json.loads((preview/'plan.json').read_text());original=json.loads((results/'result.json').read_text())
    report={'schema':'ascent.complex-movie-validation.v1','purpose':'post-hoc diagnostics; original scores unchanged',
            'additionalProviderCalls':0,'originalResultSha256':hashlib.sha256((results/'result.json').read_bytes()).hexdigest(),
            'sourceTransfer':[],'witnesses':{}}
    with Engine() as engine:
        for case in plan['cases']:
            source=study.source_for(plan['source'],case)
            report['witnesses'][case['name']]=witnesses(engine,source,case)
        records=original.get('records',original.get('calls',[]))
        for i,record in enumerate(records):
            compact_run='records' not in original
            if compact_run:record={**record,'arm':'reuse'}
            if record['arm']=='direct':continue
            case=next(c for c in plan['cases'] if c['name']==record['case'])
            try:
                raw_path=results/f'{i:02d}.raw.txt' if compact_run else results/f'{i:02d}'/'raw.txt'
                candidate,count=singleton_heads(json.loads(raw_path.read_text()))
                grades=[]
                for withdrawal in (None,['Q18002795','Q208026'],['Q25188','Q123351']):
                    variant={**case,'withdrawal':withdrawal};source=study.source_for(plan['source'],variant)
                    views=study.materialize(engine,source) if record['arm']=='reuse' else None
                    actual=study.case_program(engine,source,variant,candidate,views)
                    expected=study.case_program(engine,source,variant,study.gold(variant))
                    equal=rows_equal(actual, expected)
                    grades.append({'withdrawal':withdrawal,'correct':equal,'answers':len(actual)})
                diagnostic={'case':case['name'],'arm':record['arm'],'originalOutcome':record['outcome'],
                            'singletonHeadRepairs':count,'transfers':grades}
            except Exception as error:
                diagnostic={'case':case['name'],'arm':record['arm'],'originalOutcome':record['outcome'],
                            'failure':str(error)[:2048]}
            report['sourceTransfer'].append(diagnostic)
            print('COMPLEX-SOURCE-TRANSFER',record['case'],record['arm'],diagnostic.get('transfers',diagnostic.get('failure')),flush=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')


def recover(preview,results,library,output):
    """Two adaptive calls: self-review and a schema-only matched control."""
    plan=json.loads((preview/'plan.json').read_text())
    original=json.loads((results/'result.json').read_text())
    i=next(i for i,r in enumerate(original['records']) if r['outcome']=='admission_or_execution_failure')
    record=original['records'][i];raw=(results/f'{i:02d}'/'raw.txt').read_text()
    item=next(x for x in plan['order'] if x['case']==record['case'] and x['arm']==record['arm'])
    request=json.loads((preview/item['request']).read_text())
    control={**request,'text':{'format':output_format()}}
    review={'model':'deepseek-flash','reasoning':{'effort':'high'},'max_output_tokens':MAX_OUTPUT_TOKENS,
            'stream':True,'store':False,'input':[{'role':'user','content':
            'Review this observable protocol failure. The provider completed; the engine expected rule head '
            'to be an array of atoms but received an object. Explain the defect and suggest an interface improvement. '
            'Do not infer hidden reasoning or solve the movie query. Return JSON with diagnosis and recommendations.\n'+raw}]}
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    report={'schema':'ascent.complex-movie-recovery.v1','purpose':'adaptive diagnostic; original scores unchanged',
            'maxCalls':2,'changedControlFields':['text'],'originalCase':record['case'],'originalArm':record['arm'],'calls':[]}
    (output/'plan.json').write_text(json.dumps(report,indent=2)+'\n')
    for index,req in enumerate((review,control)):
        (output/f'{index:02d}.request.json').write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n')
        print('COMPLEX-RECOVERY-CALL',index+1,'/2',flush=True)
        answer,meta=provider(req,key,output/f'{index:02d}.response.json')
        (output/f'{index:02d}.raw.txt').write_text(answer)
        result={'outcome':response_outcome(meta),'usage':(meta['terminal'] or {}).get('usage'),
                'providerSeconds':meta['providerSeconds'],'requestSha256':hashlib.sha256(study.encoded(req)).hexdigest()}
        if result['outcome']=='completed_ungraded':
            try:
                candidate=json.loads(answer)
                if index==0:result['review']=candidate
                else:
                    case=next(c for c in plan['cases'] if c['name']==record['case']);source=study.source_for(plan['source'],case)
                    with Engine() as engine:
                        views=study.materialize(engine,source) if record['arm']=='reuse' else None
                        actual=study.case_program(engine,source,case,candidate,views)
                        correct=rows_equal(actual, plan['gold'][case['name']])
                    result['outcome']=response_outcome(meta,correct);result['answer']=actual
            except Exception as error:result['outcome']='invalid_recovery';result['failure']=str(error)[:2048]
        report['calls'].append(result)
        (output/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        print('\nCOMPLEX-RECOVERY-RESULT',result['outcome'],flush=True)
        if meta['error'] or (meta['terminal'] or {}).get('status')=='failed':break


def review_semantics(preview,results,library,output):
    """Model critiques its wrong contract using original question, not gold rows."""
    plan=json.loads((preview/'plan.json').read_text());original=json.loads((results/'result.json').read_text())
    i=next(i for i,r in enumerate(original['records']) if r['outcome']=='answer_mismatch')
    record=original['records'][i]
    item=next(x for x in plan['order'] if x['case']==record['case'] and x['arm']==record['arm'])
    before=json.loads((preview/item['request']).read_text());raw=(results/f'{i:02d}'/'raw.txt').read_text()
    request=copy.deepcopy(before)
    request['input'][0]['content']+=('\nReview your previous executable contract against the original question. '
        'Its answer failed an external exact-set check. No expected answers are supplied. '
        'Inspect how conjunction/union and exclusion attachment are encoded; a shared rule body is conjunction, '
        'multiple rules are union. Return {diagnosis: string, contract: {relations, rules}} with the corrected contract. '
        'Do not enumerate answers. Previous contract:\n'+raw)
    schema={'type':'object','properties':{'diagnosis':{'type':'string'},'contract':output_format()['schema']},
            'required':['diagnosis','contract'],'additionalProperties':False}
    request['text']={'format':{'type':'json_schema','name':'ascent_contract_review','schema':schema}}
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    (output/'request.json').write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n')
    report={'schema':'ascent.complex-movie-semantic-review.v1','purpose':'adaptive failure diagnosis, original score unchanged',
            'maxCalls':1,'originalCase':record['case'],'originalArm':record['arm'],'goldAnswersSupplied':False}
    (output/'plan.json').write_text(json.dumps(report,indent=2)+'\n')
    print('COMPLEX-SEMANTIC-REVIEW-CALL 1/1',flush=True)
    answer,meta=provider(request,key,output/'response.json');(output/'raw.txt').write_text(answer)
    report.update(outcome=response_outcome(meta),usage=(meta['terminal'] or {}).get('usage'),providerSeconds=meta['providerSeconds'])
    if report['outcome']=='completed_ungraded':
        try:
            prediction=json.loads(answer);case=next(c for c in plan['cases'] if c['name']==record['case'])
            source=study.source_for(plan['source'],case)
            with Engine() as engine:
                views=study.materialize(engine,source) if record['arm']=='reuse' else None
                actual=study.case_program(engine,source,case,prediction['contract'],views)
                equal=rows_equal(actual, plan['gold'][case['name']])
            report.update(outcome=response_outcome(meta,equal),diagnosis=prediction['diagnosis'],contract=prediction['contract'],answer=actual)
        except Exception as error:report.update(outcome='invalid_review',failure=str(error)[:2048])
    (output/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('\nCOMPLEX-SEMANTIC-REVIEW-RESULT',report['outcome'],flush=True)


def compact(preview,results,library,output):
    """Three adaptive interface probes; facts remain in the typed executor."""
    plan=json.loads((preview/'plan.json').read_text())
    if plan.get('stratum')!='country-qualified' or len(plan['cases'])!=3:raise ValueError('country-qualified plan required')
    requests=[]
    for case in plan['cases']:
        item=next(x for x in plan['order'] if x['case']==case['name'] and x['arm']=='reuse')
        before=json.loads((preview/item['request']).read_text())
        req=compact_request(before,study.identity(study.source_for(plan['source'],case)))
        requests.append((case,req))
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    report={'schema':'ascent.compact-movie-interface.v1','purpose':'adaptive interface probe, not held-out benchmark',
            'maxCalls':3,'retries':0,'contextChange':'remove row enumeration and actor domain; add precise view semantics',
            'basePlanSha256':hashlib.sha256((preview/'plan.json').read_bytes()).hexdigest(),'calls':[]}
    for i,(_,req) in enumerate(requests):
        (output/f'{i:02d}.request.json').write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n')
    (output/'plan.json').write_text(json.dumps(report,indent=2)+'\n')
    cache={}
    with Engine() as engine:
        for i,(case,req) in enumerate(requests):
            source=study.source_for(plan['source'],case);sid=study.identity(source);started=time.monotonic()
            hit=sid in cache
            if not hit:cache[sid]=study.materialize(engine,source)
            setup=time.monotonic()-started
            print('COMPACT-INTERFACE-CALL',i+1,'/3',case['name'],flush=True)
            raw,meta=provider(req,key,output/f'{i:02d}.response.json');(output/f'{i:02d}.raw.txt').write_text(raw)
            result={'case':case['name'],'outcome':response_outcome(meta),'usage':(meta['terminal'] or {}).get('usage'),
                    'providerSeconds':meta['providerSeconds'],'viewSetupSeconds':setup,'viewCacheHit':hit,
                    'requestSha256':hashlib.sha256(study.encoded(req)).hexdigest()}
            if result['outcome']=='completed_ungraded':
                try:
                    candidate=json.loads(raw)
                    actual=study.case_program(engine,source,case,candidate,cache[sid])
                    correct=rows_equal(actual, plan['gold'][case['name']])
                    result.update(outcome=response_outcome(meta,correct),answer=actual)
                except Exception as error:result.update(outcome='admission_or_execution_failure',failure=str(error)[:2048])
            report['calls'].append(result)
            (output/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
            print('\nCOMPACT-INTERFACE-RESULT',result['outcome'],flush=True)
            if meta['error'] or (meta['terminal'] or {}).get('status')=='failed':break


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--recover',action='store_true')
    p.add_argument('--review-semantics',action='store_true')
    p.add_argument('--compact',action='store_true')
    for name in ('preview','results','library','output'):p.add_argument(name,type=Path)
    a=p.parse_args()
    fn=compact if a.compact else review_semantics if a.review_semantics else recover if a.recover else validate
    fn(a.preview.resolve(),a.results.resolve(),a.library.resolve(),a.output.resolve())


if __name__=='__main__':main()
