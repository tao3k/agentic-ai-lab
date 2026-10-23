# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Fresh-root repository comparison with executed domain observations."""
import argparse
from datetime import datetime, timezone
import hashlib
import inspect
import json
from pathlib import Path
import shutil

from . import repository_model_study as study
from .domain_observations import row_normalization
from .repository_corpus import tree_identity, test_receipt, qualify, provenance

BASE = study.ROOT/'.cache/ascent/domain-study'
GRAPH_EXTRA = '''
def reference_effective_size(G, u):
    neighbors=set(G[u]) | (set(G.pred[u]) if G.is_directed() else set())
    def mutual(a,b):
        return (G[a][b].get('weight',1) if G.has_edge(a,b) else 0)+(G[b][a].get('weight',1) if G.has_edge(b,a) else 0)
    if not neighbors:return float('nan')
    total=sum(mutual(u,w) for w in neighbors)
    answer=0
    for v in neighbors:
        vn=set(G[v]) | (set(G.pred[v]) if G.is_directed() else set())
        maximum=max(mutual(v,w) for w in vn)
        answer+=1-sum(mutual(u,w)/total*mutual(v,w)/maximum for w in neighbors)
    return answer

def test_domain_heldout():
    for directed in (False,True):
        for scale in (1,3,7):
            G=nx.DiGraph() if directed else nx.Graph()
            G.add_weighted_edges_from([(10,11,2*scale),(10,12,5*scale),(11,12,3*scale),(12,13,7*scale),(13,14,11*scale),(14,10,4*scale)])
            G.add_node(99)
            actual=nx.effective_size(G,weight='weight')
            for node in G:
                expected=reference_effective_size(G,node)
                if math.isnan(expected):assert math.isnan(actual[node])
                else:assert actual[node]==pytest.approx(expected,abs=1e-9)
'''
ODE_EXTRA = '''
def test_domain_heldout():
    t=symbols('heldout_t');y=Function('heldout_y')(t)
    for a in (1,2,3):
        equation=y.diff(t,2)+2*a*y.diff(t)+a*a*y
        result=dsolve(equation,y,ics={y.subs(t,0):0})
        assert isinstance(result,Eq)
        assert checkodesol(equation,result,func=y)[0]
        assert result.rhs.subs(t,0)==0
        constants=result.rhs.free_symbols-{t}
        assert len(constants)==1
        constant=next(iter(constants))
        assert (result.rhs-constant*t*exp(-a*t)).expand()==0
'''


def cases():
    graph_prefix='import ast,inspect,sys,textwrap,json\nfrom fractions import Fraction\n'+inspect.getsource(row_normalization)+'\n'
    graph_probe=graph_prefix+'''import networkx as nx
G=nx.DiGraph();G.add_weighted_edges_from([(0,1,2),(0,2,5),(1,0,3),(2,1,7)])
print(json.dumps(row_normalization(nx.effective_size,G)))
'''
    ode_probe='''import json
from sympy import symbols,Function,dsolve,simplify
t=symbols('t');y=Function('y')(t)
result=dsolve(y.diff(t,2)+2*y.diff(t)+y,y,ics={y.subs(t,0):0})
solutions=result if isinstance(result,list) else [result]
families=[s for s in solutions if s.rhs.free_symbols-{t}]
present=any(s.rhs==0 for s in solutions)
residual='unknown'
if families:
 rhs=families[0].rhs;constants=rhs.free_symbols-{t}
 residual=str(simplify(rhs.subs({c:0 for c in constants})))
print(json.dumps({'value':[str(s) for s in solutions],'observations':[['zero-specialization',residual,present]]}))
'''
    common=json.loads((BASE/'qualification/cases.json').read_text())
    for case in common:
        case['targets'].append(case['testFile']+'::test_domain_heldout')
        case['domainKind']='graph-row-normalization' if case['package']=='networkx' else 'symbolic-specialization'
        case['reproducer']=graph_probe if case['package']=='networkx' else ode_probe
        case['question']=(
            'Repair effective_size so its sparse/vectorized and iterative paths agree with the structural-hole definition on weighted directed and undirected graphs. Preserve isolated-node NaN behavior, arbitrary node labels, positive-weight scaling invariance and neighboring constraint computations. Diagnose how mutual-weight normalization and the redundancy matrix interact; the weighted directed reproducer uses edges (0,1,2),(0,2,5),(1,0,3),(2,1,7). Repair general behavior, not one fixture. You may inspect both existing paths. run_reproducer also returns actual pre/post normalization rows.'
            if case['package']=='networkx' else
            'Repair dsolve result assembly after initial conditions: y\'\'+2*y\'+y=0 with y(0)=0 can return both a parameterized family and its zero specialization. Return a nonredundant solution set while retaining all mathematically distinct branches and preserving simplify=False behavior. Handle the family y\'\'+2*a*y\'+a^2*y=0 for positive integer a as well as existing nonlinear branch controls. Trace condition application, constant solving and redundancy elimination; do not discard every constant solution. run_reproducer returns current solutions and a delegated symbolic specialization witness.')
    return common


def prepare(destination):
    destination=destination.resolve();destination.mkdir(parents=True,exist_ok=False)
    tasks=cases()
    frozen_at=datetime.now(timezone.utc).isoformat()
    for case in tasks:
        source=BASE/case['name'];target=destination/case['name'];target.mkdir()
        study.copy_snapshot(source/'parent',target/'parent')
        case['snapshotIdentity'],case['files']=tree_identity(target/'parent')
        original=(source/'fixed'/case['testFile']).read_text()
        (target/'grading.py').write_text(original+(GRAPH_EXTRA if case['package']=='networkx' else ODE_EXTRA))
        case['graderSha256']=hashlib.sha256((target/'grading.py').read_bytes()).hexdigest()
        metadata=json.loads((source/'metadata.json').read_text())
        # New window is explicit before this run, not retroactively applied to the prior study.
        case['provenance']=provenance(metadata,earliest='2026-09-01T00:00:00Z',frozen_at=frozen_at)
        if not case['provenance']['eligible']:raise ValueError('source provenance not admitted')
        receipts=[]
        for label in ('parent','fixed'):
            run=target/('qualification-'+label);run.mkdir()
            workspace=study.Workspace(destination,run,case,'ordinary-tools')
            if label=='fixed':
                for relative in case['editable']:shutil.copy2(source/'fixed'/relative,workspace.root/relative)
                workspace.regenerate()
            print('DOMAIN-QUALIFY',case['name'],label,flush=True)
            result=workspace.execute(grading=True)
            receipt=test_receipt(run/'execution-1/tests.xml',result['exitCode']);receipts.append(receipt)
            print('DOMAIN-QUALIFY-RESULT',case['name'],label,result['counts'],flush=True)
            workspace.close()
        transition=qualify(*receipts)
        if not transition['qualified']:raise ValueError('augmented grader failed qualification')
        case['qualification']=transition
        case['expectedTestNames']=sorted(name for _,name in receipts[1]['cases'])
    shutil.copy2(study.ROOT/'.gerbil/lib/libascent.dylib',destination/'libascent.dylib')
    paths=[Path(__file__),Path(study.__file__),Path(inspect.getfile(row_normalization)),
           *[study.ROOT/'python/src/ascent'/name for name in ('domain_evidence.py','derivations.py','evidence.py','conversation.py','__init__.py')],
           *[study.ROOT/'workbench/src/agentic_ai_lab_testing.assessment_studies'/name for name in ('model_study.py','movie_study.py','inference_effort.py','inference_reuse_study.py','repository_corpus.py','evidence_chain_study.py')],
           study.ROOT/'applications/domain-evidence.ss',study.ROOT/'interface/engine-api.ss']
    hashes={str(p.relative_to(study.ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    for p in paths:
        out=destination/'producer-snapshot'/p.relative_to(study.ROOT);out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,out)
    plan={'schema':'ascent.domain-repository-study.v1','tasks':tasks,'arms':list(study.ARMS),'repetitions':2,'maxTurns':40,'maxOutputTokens':131072,'workers':2,'producerHashes':hashes,'verifyCandidatesOnEdit':True,
          'librarySha256':hashlib.sha256((destination/'libascent.dylib').read_bytes()).hexdigest(),
          'disclosureWindow':'2026-09-01 onward; independent root causes from previous primary tasks; exposure unknown',
          'frozenAt':frozen_at,
          'scope':'Two new root causes. Domain checks over executed values and retained contract feedback. Localized algorithms; not calibrated high difficulty. Uniform 40-turn primary ceiling, no adaptive extension.'}
    (destination/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('DOMAIN-PLAN-FROZEN tasks=2 trajectories=12 ceiling=40',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=('prepare','live'));parser.add_argument('plan',type=Path);parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.mode=='prepare':prepare(args.plan)
    else:
        if args.output is None:parser.error('--output required for live')
        study.live(args.plan,args.output)
