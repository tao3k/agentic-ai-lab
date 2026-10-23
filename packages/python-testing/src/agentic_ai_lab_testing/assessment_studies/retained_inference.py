# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Replay finite retained-query observations in the Scheme engine through the Rust/PyO3 runtime."""
import argparse
import importlib.util
import hashlib
import json
import copy
from pathlib import Path
from ascent import Engine, EngineError
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from .complex_movie_study import atom, rule, var, declaration


def qualify(corpus, library, output):
    extension = Path(importlib.util.find_spec('ascent._core').origin).resolve()
    if library.resolve() != extension:
        raise ValueError('qualification requires the installed PyO3 extension')
    observations=json.loads(corpus.read_text());actual=[];stale_faults=0
    domains={'Actor':['actor0','actor1']}
    a,b,c=(var(n) for n in ('a','b','c'))
    def edges(source):return [[f'actor{i//2}',f'actor{i%2}'] for i in range(4) if source//(2**i)%2]
    def program(source):return {
        'relations':[declaration('edge',['Actor','Actor'],True,edges(source),domains),
                     declaration('target',['Actor'],True,[['actor0']],domains),
                     declaration('reachable',['Actor','Actor'],False,[],domains),
                     declaration('answer',['Actor'],False,[],domains)],
        'rules':[rule(atom('reachable',a,b),atom('edge',a,b)),
                 rule(atom('reachable',a,c),atom('reachable',a,b),atom('edge',b,c)),
                 rule(atom('answer',a),atom('reachable',a,b),atom('target',b))],
        'queries':['answer']}
    def mask(result):
        if not result['complete']:raise ValueError('incomplete retained query')
        return sum(2**int(row[0][-1]) for row in result['relations']['answer'])
    with Engine() as engine, ReasoningRuntime() as assessment:
        for source in range(16):
            with engine.open(program(source)) as session:
                first=session.run();old=mask(first)
                try: session.run(0); raise AssertionError('zero deadline admitted')
                except EngineError: pass
                if session.run()['relations']!=first['relations']:raise ValueError('exact repeat changed')
                for phase in range(2):
                    now=source-4 if phase and source//4%2 else source
                    if phase:session.replace({'edge':edges(now)})
                    result=session.run();value=mask(result)
                    try: session.run(0); raise AssertionError('zero deadline admitted')
                    except EngineError: pass
                    if session.run()['relations']!=result['relations']:raise ValueError('updated retained result differs')
                    with engine.open(program(now)) as fresh:
                        if mask(fresh.run())!=value:raise ValueError('retained/fresh evaluation differs')
                    actual.append([source,phase,now,value,int(source==now)])
                    if phase and old!=value:stale_faults+=1
            p=program(source)
            with EvidenceStore(assessment,[r for r in p['relations'] if r['source']]) as evidence:
                for phase in range(2):
                    now=source-4 if phase and source//4%2 else source
                    current=program(now)
                    if phase:evidence.replace([r for r in current['relations'] if r['source']])
                    subgoal=copy.deepcopy(current);subgoal['queries']=['reachable']
                    established=evidence.query(subgoal)
                    alias=established['publishedEvidence'][0]['relation']
                    extension={'relations':[r for r in current['relations'] if r['name']!='reachable'],
                               'rules':[rule(atom('answer',a),atom(alias,a,b),atom('target',b))],
                               'queries':['answer']}
                    extended=evidence.query(extension)
                    observation=actual[-2+phase]
                    if mask(extended['result'])!=observation[3]:raise ValueError('published subgoal extension differs')
                    if not evidence.query(extension)['retainedCompleted']:raise ValueError('extended path did not retain completion')
            print('RETAINED-INFERENCE-SOURCE',source+1,'/16',flush=True)
    if actual!=observations or stale_faults!=8:raise ValueError('finite correspondence or stale-answer control failed')
    output.write_text(json.dumps({'schema':'ascent.retained-inference-correspondence.v1',
        'observations':len(actual),'changedSourceStaleAnswerFaultsDetected':stale_faults,
        'publishedSubgoalExtensionObservations':len(actual),
        'corpusSha256':hashlib.sha256(corpus.read_bytes()).hexdigest(),
        'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()},indent=2)+'\n')


def main():
    p=argparse.ArgumentParser()
    for name in ('corpus','library','output'):p.add_argument(name,type=Path)
    a=p.parse_args();qualify(a.corpus,a.library,a.output)


if __name__=='__main__':main()
