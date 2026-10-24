# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Real repository repair pilot with source-bound Scheme evidence and matched arms."""
import argparse
import ast
import concurrent.futures
import contextlib
import copy
import hashlib
import json
import multiprocessing
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import DomainEvidence
from agentic_ai_lab_runtime.reasoning import identity
from .evidence_chain_study import loose_json
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price
from .model_study import provider, response_outcome
from .movie_study import provider_key
from .repository_corpus import tree_identity, test_receipt, qualify, provenance

ROOT = Path.cwd().resolve()
CORPUS = ROOT / '.cache/ascent/repository-study'
ARMS = ('ordinary-tools', 'scheme-fresh', 'scheme-retained')
ENGINE = None
CASES = [
    {'name': 'group-centrality-order', 'metadata': 'networkx-8931', 'package': 'networkx',
     'editable': ['networkx/algorithms/centrality/group.py'],
     'testFile': 'networkx/algorithms/centrality/tests/test_group.py',
     'targets': ['networkx/algorithms/centrality/tests/test_group.py::TestGroupBetweennessCentrality'],
     'development': ['networkx/algorithms/centrality/tests/test_group.py::TestGroupBetweennessCentrality'],
     'question': 'Repair group_betweenness_centrality: on a directed graph, permuting the same group members can change its value. A path 0->1->2->3->4, a disjoint path 6->7->8->9->10, and additional edges 3->2->1 give different results for [1,3,7,9] and [9,7,3,1] with normalized=False. The result must be independent of group ordering. Preserve directed and undirected behavior, weighted shortest paths, endpoint inclusion, normalization, and disconnected-component handling. Diagnose the interaction among shortest-path counts and accumulated group contributions; repair the implementation without replacing it with a hard-coded answer.',
     'reproducer': 'import json,networkx as nx\nG=nx.path_graph(5,create_using=nx.DiGraph);nx.add_path(G,range(6,11));nx.add_path(G,[3,2,1])\nprint(json.dumps({"forward":nx.group_betweenness_centrality(G,[1,3,7,9],normalized=False),"reverse":nx.group_betweenness_centrality(G,[9,7,3,1],normalized=False)}))\n'},
    {'name': 'series-root-precision', 'metadata': 'sympy-30699', 'package': 'sympy',
     'editable': ['sympy/polys/ring_series.py', 'sympy/polys/puiseux.py'],
     'testFile': 'sympy/polys/tests/test_ring_series.py',
     'targets': ['sympy/polys/tests/test_ring_series.py::test_issue_30698', 'sympy/polys/tests/test_ring_series.py::test_nth_root', 'sympy/polys/tests/test_ring_series.py::test_inversion'],
     'development': ['sympy/polys/tests/test_ring_series.py::test_inversion'],
     'question': 'Repair rs_nth_root for inputs whose leading exponent is nonzero. For p=x+x**2, rs_nth_root(p,-1,x,3) drops x-x**2 whereas rs_series_inversion preserves those terms. For p=x**4+x**5, the square root at precision 3 returns zero instead of x**2. Precision excludes terms at or above the requested exponent. Handle reciprocal and positive fractional roots, rational exponents, multivariate coefficients and precision boundaries consistently; preserve existing series inversion and root behavior. Trace normalization, recursive expansion and leading-power restoration before repairing the general case.',
     'reproducer': 'import json\nfrom sympy import QQ\nfrom sympy.polys.puiseux import puiseux_ring\nfrom sympy.polys.ring_series import rs_nth_root,rs_series_inversion\nR,x=puiseux_ring("x",QQ);p=x+x**2\nprint(json.dumps({"reciprocal":str(rs_nth_root(p,-1,x,3).as_expr()),"inversion":str(rs_series_inversion(p,x,3).as_expr()),"squareRoot":str(rs_nth_root(x**4+x**5,2,x,3).as_expr())}))\n'}]


def copy_snapshot(source, destination):
    # GitHub archive links and generated files are not model-visible inputs.
    ignored = shutil.ignore_patterns('__pycache__', '.pytest_cache', '.git', '.hypothesis')
    shutil.copytree(source, destination, ignore=ignored, symlinks=True)
    for path in destination.rglob('*'):
        if path.is_symlink(): path.unlink()


def prepare(directory):
    directory.mkdir(parents=True, exist_ok=False)
    audit = json.loads((CORPUS / 'fresh-source-audit.json').read_text())
    tasks = []
    for case in CASES:
        case = copy.deepcopy(case)
        record = json.loads((CORPUS / 'discovery-20261010' / (case['metadata'] + '.json')).read_text())
        admitted = provenance(record, earliest=audit['earliestDisclosure'], frozen_at=audit['provenanceCutoff'])
        if not admitted['eligible']: raise ValueError('task provenance failed')
        receipts = [test_receipt(CORPUS/case['name']/(label+'.xml'), json.loads((CORPUS/case['name']/(label+'.exit.json')).read_text())['exitCode']) for label in ('before','after')]
        if not qualify(*receipts)['qualified']: raise ValueError('task execution qualification failed')
        case['expectedTestNames']=sorted(name for _,name in receipts[1]['cases'])
        destination = directory/case['name']; destination.mkdir()
        copy_snapshot(CORPUS/case['name']/'parent', destination/'parent')
        case['snapshotIdentity'], case['files'] = tree_identity(destination/'parent')
        shutil.copy2(CORPUS/case['name']/'fixed'/case['testFile'], destination/'grading.py')
        case['graderSha256'] = hashlib.sha256((destination/'grading.py').read_bytes()).hexdigest()
        case['provenance'] = admitted
        tasks.append(case)
    library = ROOT/'.gerbil/lib/libascent.dylib'; shutil.copy2(library, directory/'libascent.dylib')
    paths = [Path(__file__), Path(__file__).with_name('model_study.py'), Path(__file__).with_name('movie_study.py'), Path(__file__).with_name('inference_effort.py'), Path(__file__).with_name('inference_reuse_study.py'), Path(__file__).with_name('repository_corpus.py'), Path(__file__).with_name('evidence_chain_study.py'), ROOT/'rust/ascent/src/derivations.rs', ROOT/'rust/ascent-python/src/api/evidence.rs', ROOT/'rust/ascent/src/conversation.rs', ROOT/'rust/ascent-python/src/api/exports.rs']
    hashes = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    for path in paths:
        snapshot = directory/'producer-snapshot'/path.relative_to(ROOT); snapshot.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,snapshot)
    plan = {'schema':'ascent.repository-model-study.v1','tasks':tasks,'arms':list(ARMS),'repetitions':2,'maxTurns':10,'maxOutputTokens':131072,'workers':2,'producerHashes':hashes,'verifyCandidatesOnEdit':True,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'dependencies':audit['dependencies'],'scope':'Two independently sourced repair tasks; pilot, not four-family coverage or proof of unseen training.'}
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('REPOSITORY-PLAN-FROZEN',len(tasks),'tasks',len(tasks)*2*3,'trajectories',flush=True)


def symbol_table(directory, files):
    entries = {}; edges = set()
    for relative in files:
        parsed = ast.parse((directory/relative).read_text())
        definitions = [node for node in parsed.body if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef))]
        local = {node.name:'s'+hashlib.sha256((relative+':'+node.name).encode()).hexdigest()[:20] for node in definitions}
        for node in definitions:
            token = local[node.name]; entries[token] = {'name':node.name,'file':relative,'start':node.lineno,'end':node.end_lineno}
            for call in ast.walk(node):
                if isinstance(call,ast.Call) and isinstance(call.func,ast.Name) and call.func.id in local:
                    edges.add((token,local[call.func.id]))
    return entries, sorted(edges)


def evidence_program(entries, edges, roots, snapshot=None):
    domain = sorted(entries); column = {'kind':'symbol','domain':domain}
    relations = [{'name':'Defined','columns':[column],'source':True,'rows':[[x] for x in domain]},
                 {'name':'SyntacticReference','columns':[column,column],'source':True,'rows':[list(e) for e in edges]},
                 {'name':'reachable','columns':[column,column],'source':False,'rows':[]},
                 {'name':'support','columns':[column],'source':False,'rows':[]}]
    snapshot=snapshot or identity({'entries':entries,'edges':edges})
    relations.append({'name':'Snapshot','columns':[{'kind':'symbol','domain':[snapshot]}],'source':True,'rows':[[snapshot]]})
    def var(n): return {'var':n}
    def atom(n,*terms): return {'relation':n,'terms':list(terms)}
    rules = [{'head':[atom('reachable',var('x'),var('y'))],'body':[atom('SyntacticReference',var('x'),var('y'))]},
             {'head':[atom('reachable',var('x'),var('z'))],'body':[atom('reachable',var('x'),var('y')),atom('SyntacticReference',var('y'),var('z'))]}]
    for root in roots:
        rules.extend([{'head':[atom('support',var('x'))],'body':[atom('Defined',var('x')),atom('reachable',{'const':root},var('x'))]},
                      {'head':[atom('support',{'const':root})],'body':[atom('Defined',{'const':root})]}])
    return {'relations':relations,'rules':rules,'queries':['support']}


def grading_scope(text, targets):
    """Preserve selected upstream definitions; exclude unrelated suite imports."""
    parsed=ast.parse(text);names={target.split('::')[1] for target in targets}
    imports=[n for n in parsed.body if isinstance(n,(ast.Import,ast.ImportFrom))]
    future=[n for n in imports if isinstance(n,ast.ImportFrom) and n.module=='__future__']
    imports=[n for n in imports if n not in future]
    selected=[n for n in parsed.body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in names]
    if {n.name for n in selected}!=names:raise ValueError('qualification test scope missing')
    # Preserve referenced base classes, helpers and global symbol declarations.
    # The extracted file remains grader-only; this does not expose hidden tests.
    while True:
        references={n.id for node in selected for n in ast.walk(node) if isinstance(n,ast.Name) and isinstance(n.ctx,ast.Load)}
        extra=[]
        for node in parsed.body:
            if node in selected:continue
            defined = {node.name} if isinstance(node,(ast.FunctionDef,ast.ClassDef)) else (
                {n.id for target in node.targets for n in ast.walk(target) if isinstance(n,ast.Name)} if isinstance(node,ast.Assign) else set())
            if defined & references:extra.append(node)
        if not extra:break
        selected.extend(extra)
    selected=[node for node in parsed.body if node in selected]
    # Real import lifecycle output, not timer heartbeats.
    code=[ast.get_source_segment(text,n) for n in future]
    for node in imports:
        code.append('print("TEST-SCOPE-IMPORT '+str(getattr(node,'module',None) or node.names[0].name)+'",flush=True)')
        code.append(ast.get_source_segment(text,node))
    code.extend(ast.get_source_segment(text,n) for n in selected)
    return '\n\n'.join(code)+'\n'


def observed_runner(command):
    """Emit actual dependency import progress during cold interpreter startup."""
    return '''import sys,runpy,importlib.machinery
class ObservedLoader:
 def __init__(self,name,loader):self.name,self.loader=name,loader
 def __getattr__(self,name):return getattr(self.loader,name)
 def create_module(self,spec):
  print('DEPENDENCY-IMPORT-CREATE',self.name,flush=True)
  return self.loader.create_module(spec)
 def exec_module(self,module):
  print('DEPENDENCY-IMPORT-START',self.name,flush=True)
  self.loader.exec_module(module)
  print('DEPENDENCY-IMPORT-DONE',self.name,flush=True)
class ObservedFinder:
 def find_spec(self,name,path=None,target=None):
  if name.split('.')[0] not in ('sympy','networkx','pytest','scipy','numpy') or name.count('.')>5:return None
  spec=importlib.machinery.PathFinder.find_spec(name,path,target)
  if spec and isinstance(spec.loader,(importlib.machinery.SourceFileLoader,importlib.machinery.ExtensionFileLoader)):spec.loader=ObservedLoader(name,spec.loader)
  return spec
sys.meta_path.insert(0,ObservedFinder())
print('EXECUTION-START',flush=True)
args='''+repr(command)+'''
if args[0]=='pytest':
 import pytest
 sys.exit(pytest.main(args[1:]))
else:runpy.run_path(args[0],run_name='__main__')
'''


class Workspace:
    def __init__(self, plan_dir, directory, case, arm):
        global ENGINE
        plan_dir=plan_dir.resolve();directory=directory.resolve()
        self.root = directory/'workspace'; copy_snapshot(plan_dir/case['name']/'parent', self.root)
        self.directory=directory; self.case=case; self.arm=arm; self.chain=None; self.journal=[]; self.generation=0; self.domain=None; self.sealed_candidate=None
        self.regenerate()
        if arm!='ordinary-tools':
            if ENGINE is None: ENGINE=ReasoningRuntime(plan_dir/'libascent.dylib')
            self.regenerate()
        self.grader=plan_dir/case['name']/'grading.py'

    def regenerate(self):
        if self.chain: self.chain.close(); self.chain=None
        self.entries,self.edges=symbol_table(self.root,self.case['editable'])
        self.source_identity=identity({p:hashlib.sha256((self.root/p).read_bytes()).hexdigest() for p in self.case['editable']})
        if self.arm!='ordinary-tools' and ENGINE:
            program=evidence_program(self.entries,self.edges,[],self.source_identity)
            self.chain=EvidenceChain(ENGINE,[r for r in program['relations'] if r['source']],self.arm=='scheme-retained')
            if self.case.get('domainKind'):
                if getattr(self,'domain',None):self.domain.replace_snapshot(self.source_identity)
                else:self.domain=DomainEvidence(ENGINE,self.source_identity,self.arm=='scheme-retained')

    def read(self, path, start=1, end=None):
        if path not in self.case['files'] or not path.startswith(self.case['package']+'/') or not path.endswith('.py'):
            raise ValueError('read only parent package source files; history and hidden grading artifacts are not exposed')
        lines=(self.root/path).read_text().splitlines();start=int(start);end=min(int(end or start+159),start+199,len(lines))
        if start<1: raise ValueError('line numbers begin at 1')
        result={'path':path,'start':start,'end':end,'totalLines':len(lines),'sourceIdentity':self.source_identity,'text':'\n'.join(f'{i+1}: {line}' for i,line in enumerate(lines[start-1:end],start-1))}
        if self.chain:
            roots=[token for token,e in self.entries.items() if e['file']==path and e['start']<=end and e['end']>=start]
            if roots:
                roots=roots[:16];began=time.monotonic();receipt=self.chain.query(evidence_program(self.entries,self.edges,roots,self.source_identity))
                self.journal.append({'generation':self.generation,'sourceIdentity':self.source_identity,'seconds':time.monotonic()-began,'reusedComponents':receipt['reusedComponents'],'freshComponents':receipt['freshComponents'],'pathIdentity':receipt['pathIdentity']})
                # Matched Scheme arms expose identical checked facts, not cache hints.
                result['checkedSyntacticSupport']=[self.entries[row[0]] for row in sorted(receipt['result']['relations']['support'])]
                result['evidenceScope']='Least fixed point of extracted local syntactic references; this is not a proof of Python call resolution or behavior.'
        return result

    def search(self, text, path=None):
        result=[]
        for relative in ([path] if path else self.case['editable']):
            if relative not in self.case['files'] or not relative.startswith(self.case['package']+'/'): raise ValueError('source path outside exposed snapshot')
            for number,line in enumerate((self.root/relative).read_text().splitlines(),1):
                if text in line: result.append({'path':relative,'line':number,'text':line[:500]})
                if len(result)>=50:return result
        return result

    def edit(self, edits):
        if self.sealed_candidate:raise ValueError('independently verified candidate is sealed; source updates require a new task snapshot')
        if not isinstance(edits,list) or not edits:raise ValueError('supply a nonempty list of implementation edits')
        updates={}
        for edit in edits:
            path=edit['path']
            if path not in self.case['editable']: raise ValueError('edit only the declared implementation files, never tests or runtime infrastructure')
            original=updates.get(path,(self.root/path).read_text());old=edit['old'];new=edit['new']
            if not old or original.count(old)!=1: raise ValueError('replacement must match exactly one current source fragment')
            changed=original.replace(old,new,1);parsed=ast.parse(changed)
            before=ast.parse((self.root/path).read_text())
            imports=lambda tree:{ast.dump(n) for n in ast.walk(tree) if isinstance(n,(ast.Import,ast.ImportFrom))}
            if imports(parsed)!=imports(before):raise ValueError('this pilot does not admit import changes; use the existing implementation dependencies')
            forbidden={'open','eval','exec','compile','__import__','__builtins__','__loader__','__file__','globals','locals'}
            names=lambda tree:{n.id for n in ast.walk(tree) if isinstance(n,ast.Name)}
            if (names(parsed)-names(before)) & forbidden:raise ValueError('runtime or evaluator introspection is outside the task')
            updates[path]=changed
        for path,text in updates.items():(self.root/path).write_text(text)
        self.generation+=1;self.regenerate()
        return {'edited':list(updates),'sourceIdentity':self.source_identity,'priorEvidenceInvalidated':True}

    def seal_candidate(self, grade):
        expected=len(self.case['expectedTestNames'])
        actual=identity({p:hashlib.sha256((self.root/p).read_bytes()).hexdigest() for p in self.case['editable']})
        if (grade.get('verified') is not True or grade.get('kind')!='hidden-grading'
            or grade.get('sourceIdentity')!=self.source_identity or grade.get('exitCode')!=0
            or actual!=self.source_identity
            or expected==0 or grade.get('counts')!={'passed':expected,'failed':0,'skipped':0,'error':0}):
            raise ValueError('only a current-snapshot independently verified candidate may be sealed')
        destination=self.directory/'verified-candidate';destination.mkdir(exist_ok=False)
        for relative in self.case['editable']:
            target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(self.root/relative,target)
        copied=identity({p:hashlib.sha256((destination/p).read_bytes()).hexdigest() for p in self.case['editable']})
        if copied!=self.source_identity:raise ValueError('candidate source changed while sealing')
        self.sealed_candidate={'sourceIdentity':self.source_identity,'graderSha256':self.case['graderSha256'],
                               'selectedTestNames':self.case['expectedTestNames'],'grade':copy.deepcopy(grade),
                               'path':str(destination),'scope':'Selected independent grader only; not all repository behavior.'}
        (destination/'receipt.json').write_text(json.dumps(self.sealed_candidate,indent=2)+'\n')
        return copy.deepcopy(self.sealed_candidate)

    def execute(self, *, grading=False, reproducer=False):
        number=len(list(self.directory.glob('execution-*.log')))+1
        run=self.directory/f'execution-{number}';run.mkdir();xml=run/'tests.xml'
        logpath=self.directory/f'execution-{number}.log'
        python=CORPUS/'execution-environment/bin/python'
        env={k:v for k,v in os.environ.items() if k in ('PATH','LANG','LC_ALL')}
        env.update(PYTHONPATH=str(self.root),PYTEST_DISABLE_PLUGIN_AUTOLOAD='1',PYTHONDONTWRITEBYTECODE='1',HOME=str(run),TMPDIR=str(run))
        # The child can read its workspace and dependency runtime, not .env or
        # fixed sources. It may write only this execution's temporary directory.
        allowed=[str(self.root),str(CORPUS/'environment'),'/nix/store','/System','/usr','/Library','/opt/homebrew','/private/var/db','/dev','/etc','/private/etc','/bin','/sbin']
        read_paths=[str(self.root),str(CORPUS/'execution-environment'),str(run)]
        # Platform loaders need their normal system reads. Deny user-directory
        # contents outside the three explicitly exposed evaluator directories.
        deny_reads='(require-all (require-any (subpath "/Users") (subpath "/System/Volumes/Data/Users")) '+' '.join('(require-not (subpath '+json.dumps(p)+'))' for p in read_paths)+')'
        deny_writes='(require-all (require-not (subpath '+json.dumps(str(run))+')) (require-not (literal '+json.dumps(str(logpath))+')) (require-not (subpath "/dev")))'
        # Preserve platform process/loader operations while restricting contents,
        # writes and networking. A deny-default profile broke Nix's launcher.
        profile='(version 1)(allow default)(deny network*)(deny file-read-data '+deny_reads+')(deny file-write* '+deny_writes+')'
        sandbox=run/'sandbox.sb';sandbox.write_text(profile)
        if reproducer:
            code=run/'reproducer.py';code.write_text(self.case['reproducer']);arguments=[str(code)]
        else:
            targets=self.case['targets'] if grading else self.case['development']
            text=self.grader.read_text() if grading else (self.root/self.case['testFile']).read_text()
            scope=run/'test_scope.py';scope.write_text(grading_scope(text,targets))
            (run/'pytest.ini').write_text('[pytest]\n')
            scoped=[str(scope)+'::'+target.split('::',1)[1] for target in targets]
            arguments=['pytest','-vv',*scoped,'--junitxml='+str(xml),'-c',str(run/'pytest.ini'),'-p','no:cacheprovider','-s']
        bootstrap=run/'runner.py';bootstrap.write_text(observed_runner(arguments));command=[str(python),'-u',str(bootstrap)]
        began=time.monotonic()
        with logpath.open('w') as log:
                child=subprocess.Popen(['/usr/bin/sandbox-exec','-f',str(sandbox),*command],cwd=self.root,env=env,stdout=log,stderr=subprocess.STDOUT)
                last=began;size=0
                while child.poll() is None:
                    time.sleep(.1);now=logpath.stat().st_size
                    if now!=size:size=now;last=time.monotonic()
                    if time.monotonic()-last>5:
                        child.kill();child.wait();raise TimeoutError('test execution made no actual log progress for five seconds')
                status=child.returncode
        text=logpath.read_text()
        visible='\n'.join(line for line in text.splitlines() if not line.startswith(('DEPENDENCY-IMPORT-','TEST-SCOPE-IMPORT ','EXECUTION-START')))
        if reproducer:
            result={'exitCode':status,'observedOutput':visible[-12000:],'sourceIdentity':self.source_identity,'seconds':time.monotonic()-began,'kind':'upstream-reproducer'}
            if self.case.get('domainKind') and status==0:
                observation=json.loads(visible.strip().splitlines()[-1])
                result['domainObservations']=observation['observations']
                if self.domain:
                    result['checkedDomainSupport']=self.domain.observe(self.case['domainKind'],observation['observations'],hashlib.sha256(logpath.read_bytes()).hexdigest())
            return result
        if not xml.exists():raise RuntimeError('test environment did not produce a complete receipt; exit='+str(status))
        receipt=test_receipt(xml,status);counts={state:sum(x==state for x in receipt['cases'].values()) for state in ('passed','failed','skipped','error')}
        expected=len(self.case['expectedTestNames']) if 'expectedTestNames' in self.case else len(receipt['cases'])
        names=sorted(name for _,name in receipt['cases'])
        verified=grading and status==0 and len(receipt['cases'])==expected and counts['passed']==expected and names==self.case.get('expectedTestNames',names)
        result={'verified':verified,'allChecksPassed':status==0 and counts['passed']==len(receipt['cases']) and bool(receipt['cases']),'exitCode':status,'counts':counts,'sourceIdentity':self.source_identity,'seconds':time.monotonic()-began,'kind':'hidden-grading' if grading else 'development-tests'}
        if not grading:result['observedOutput']=visible[-12000:]
        return result

    def close(self):
        if self.chain:self.chain.close()
        if getattr(self,'domain',None):self.domain.close()


def tool_definitions():
    definitions=[('read_source','Read parent/current implementation source. Lines are one-based, at most 200 per read. Scheme arms also return checked local syntactic support.',{'path':{'type':'string'},'start':{'type':'integer'},'end':{'type':'integer'}}),
                 ('search_source','Find literal text in implementation files; omitted path searches the declared implementation surfaces.',{'text':{'type':'string'},'path':{'type':'string'}}),
                 ('edit_source','Apply edits to implementation files: each edit has path, old and new. old must match one current fragment. Source changes invalidate checked evidence.',{'edits':{'type':'array','items':{'type':'object','properties':{'path':{'type':'string'},'old':{'type':'string'},'new':{'type':'string'}}}}}),
                 ('run_reproducer','Execute the original upstream bug reproducer against the current implementation.',{}),
                 ('run_checks','Run existing visible development controls against current code.',{}),
                 ('submit_patch','Grade the current repair independently. Returns counts and a verdict, without hidden test contents or the gold repair.',{})]
    return [{'type':'function','name':name,'description':description,'parameters':{'type':'object','properties':properties}} for name,description,properties in definitions]


def episode(plan,plan_dir,output,case,rep,arm):
    directory=output/f"{case['name']}-rep-{rep}-{arm}";directory.mkdir()
    record={'task':case['name'],'repetition':rep,'arm':arm,'attempts':[],'status':'running','evidenceJournal':[]}
    def save():
        if workspace is not None and workspace.domain:record['domainJournal']=copy.deepcopy(workspace.domain.journal)
        (directory/'episode.json').write_text(json.dumps(record,indent=2)+'\n')
    workspace=None
    try:
        workspace=Workspace(plan_dir,directory,case,arm)
        history=ResponseHistory(json.dumps({'question':case['question'],'implementationFiles':case['editable'],'allowedTools':[x['name'] for x in tool_definitions()]},sort_keys=True))
        instructions='Repair the complete real repository problem. Reason naturally; no subproblem-first plan is required. Use source reads, original reproductions and executable controls. Only declared implementation files are editable. No network, git history, grader files or runtime introspection are available. Source reads may include checked syntactic support; it is evidence about extracted references, not proof of runtime behavior. Keep code general and preserve existing semantics. Submit the current repair for independent grading; unsuccessful repairs may be revised. Function calls are automatic, not forced. Prose and an unambiguous JSON edit payload are accepted. Do not alter imports or grading infrastructure in this bounded pilot.'
        if case.get('domainKind'):
            instructions+=' Reproducer observations may also have Scheme-checked domain constraints. Treat them as scoped facts about observed executions. Retained domain context labels the current snapshot; edits invalidate prior-snapshot claims while checker-qualified mathematical contracts remain applicable.'
        key=provider_key();save()
        with (directory/'progress.log').open('w') as log,contextlib.redirect_stdout(log):
            for turn in range(1,plan['maxTurns']+1):
                if workspace.domain and workspace.arm=='scheme-retained' and workspace.domain.laws:
                    history.append_feedback({'retainedDomainContext':workspace.domain.summary(),
                                             'guidance':'Reuse these checked contracts and current-snapshot observations when reasoning about the complete problem. Prior-snapshot claims are invalidated after edits.'})
                request={'model':'deepseek-flash','input':history.input(),'instructions':instructions,'tools':tool_definitions(),'tool_choice':'auto','reasoning':{'effort':'high'},'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}
                (directory/f'{turn}.request.json').write_text(json.dumps(request,indent=2)+'\n')
                raw,meta=provider(request,key,directory/f'{turn}.response.json')
                terminal=meta.get('terminal')or{};attempt={'turn':turn,'providerCalls':1,'usage':terminal.get('usage'),'correct':False,'providerOutcome':response_outcome(meta),'providerSeconds':meta['providerSeconds'],'actions':[],'sourceIdentity':workspace.source_identity}
                record['attempts'].append(attempt);save()
                if meta.get('error') or not attempt['usage']:
                    attempt['error']=meta.get('error');record['status']='transport_failure';break
                calls=history.append_response(terminal)
                if not calls:
                    try:
                        try:payload=loose_json(raw)
                        except (ValueError,TypeError):payload=None
                        if isinstance(payload,dict) and 'edits' in payload:
                            changed=workspace.edit(payload['edits'])
                            attempt['actions'].append({'name':'implicit_edit','result':changed})
                        feedback=workspace.execute(grading=True)
                        if feedback['verified'] and plan.get('verifyCandidatesOnEdit'):workspace.seal_candidate(feedback)
                        attempt['correct']=feedback['verified']
                        attempt['actions'].append({'name':'implicit_submit','result':feedback});history.append_feedback(feedback)
                    except Exception as error:
                        attempt['correct']=False
                        failure={'error':type(error).__name__+': '+str(error)[:1500],'guidance':'Use the available tools to read, repair and submit the current implementation.'}
                        attempt['actions'].append({'name':'implicit_submit','result':failure});history.append_feedback(failure)
                        if failure['error'].startswith(('RuntimeError: test environment','TimeoutError: test execution')):record['status']='harness_failure'
                for call in calls:
                    action={'name':call['name'],'callId':call['call_id']};attempt['actions'].append(action)
                    try:
                        if attempt['correct']:result={'skipped':'repair already verified'}
                        elif call.get('status')=='incomplete':raise ValueError('Incomplete tool arguments; continue with a complete call.')
                        else:
                            args=loose_json(call['arguments'])
                            if call['name']=='read_source':result=workspace.read(args['path'],args.get('start',1),args.get('end'))
                            elif call['name']=='search_source':result=workspace.search(args['text'],args.get('path'))
                            elif call['name']=='edit_source':
                                result=workspace.edit(args['edits'])
                                if plan.get('verifyCandidatesOnEdit'):
                                    grade=workspace.execute(grading=True)
                                    attempt.setdefault('candidateChecks',[]).append(grade)
                                    if grade['verified']:
                                        result['verifiedCandidate']=workspace.seal_candidate(grade)
                                        attempt['correct']=True
                            elif call['name']=='run_reproducer':result=workspace.execute(reproducer=True)
                            elif call['name']=='run_checks':result=workspace.execute()
                            elif call['name']=='submit_patch':result=workspace.execute(grading=True);attempt['correct']=result['verified']
                            else:raise ValueError('unknown tool')
                    except Exception as error:result={'error':type(error).__name__+': '+str(error)[:1500]}
                    action['result']=result;history.append_result(call['call_id'],result)
                    if isinstance(result,dict) and result.get('exitCode')==65:
                        record['status']='harness_failure'
                    if isinstance(result,dict) and result.get('error','').startswith(('RuntimeError: test environment','TimeoutError: test execution')):
                        record['status']='harness_failure'
                record['evidenceJournal']=workspace.journal;save()
                if record['status']=='harness_failure':break
                if attempt['correct']:record['status']='verified';break
        if record['status']=='running':record['status']='censored'
    except Exception as error:
        record['status']='harness_failure';record['error']=type(error).__name__+': '+str(error)[:1500]
    finally:
        if workspace:workspace.close()
        record['effort']=until_verified(record['attempts']);save()
    print('REPOSITORY-EPISODE',case['name'],rep,arm,record['status'],'calls='+str(len(record['attempts'])),flush=True)
    return record


def live(plan_dir,output):
    plan_dir=plan_dir.resolve();output=output.resolve()
    plan=json.loads((plan_dir/'plan.json').read_text())
    for path,sha in plan['producerHashes'].items():
        if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=sha:raise ValueError('producer drift')
    if hashlib.sha256((plan_dir/'libascent.dylib').read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine drift')
    for case in plan['tasks']:
        if tree_identity(plan_dir/case['name']/'parent')[0]!=case['snapshotIdentity']:raise ValueError('parent source drift')
        if hashlib.sha256((plan_dir/case['name']/'grading.py').read_bytes()).hexdigest()!=case['graderSha256']:raise ValueError('grader drift')
    output.mkdir(parents=True,exist_ok=False);(plan_dir/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.repository-model-result.v1','planSha256':hashlib.sha256((plan_dir/'plan.json').read_bytes()).hexdigest(),'episodes':[],'complete':False}
    def add(record):
        receipt['episodes'].append(record);(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    jobs=[]
    arms=tuple(plan['arms'])
    for i,case in enumerate(plan['tasks']):
        for rep in range(plan['repetitions']):
            offset=(i+rep)%len(arms);order=arms[offset:]+arms[:offset]
            jobs.extend((case,rep,arm) for arm in order)
    add(episode(plan,plan_dir,output,*jobs.pop(0)))
    if receipt['episodes'][-1]['status'] in ('transport_failure','harness_failure'):raise RuntimeError('first real trajectory did not qualify transport and execution; no fan-out')
    with concurrent.futures.ProcessPoolExecutor(max_workers=plan['workers'],mp_context=multiprocessing.get_context('spawn'),max_tasks_per_child=1) as pool:
        iterator=iter(jobs);pending={pool.submit(episode,plan,plan_dir,output,*next(iterator)) for _ in range(plan['workers'])}
        while pending:
            done,pending=concurrent.futures.wait(pending,return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                record=future.result();add(record)
                if record['status'] in ('transport_failure','harness_failure'):
                    for other in pending:other.cancel()
                    raise RuntimeError('stop new dispatch after transport or harness failure')
                job=next(iterator,None)
                if job:pending.add(pool.submit(episode,plan,plan_dir,output,*job))
    receipt['complete']=True;add_marker=output/'result.json';add_marker.write_text(json.dumps(receipt,indent=2)+'\n')
    print('REPOSITORY-STUDY-COMPLETE',len(receipt['episodes']),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=('prepare','live'));parser.add_argument('source',type=Path);parser.add_argument('output',nargs='?',type=Path);args=parser.parse_args()
    prepare(args.source) if args.mode=='prepare' else live(args.source,args.output)
