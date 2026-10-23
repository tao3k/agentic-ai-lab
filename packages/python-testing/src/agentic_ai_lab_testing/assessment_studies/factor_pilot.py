# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Paid bounded pilot: Python owns byte IO/cost; frozen Scheme owns semantics."""
import argparse,hashlib,json,os,selectors,subprocess,time,shutil
from datetime import datetime,timezone
from pathlib import Path
from .model_study import provider,response_outcome
from .movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory
ROOT=Path.cwd().resolve()
BASE=ROOT/'.cache/ascent/factor-pilot'
SNAP=BASE/'snapshot'
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
class SchemeEngine:
 def __init__(self):
  env=os.environ.copy();env['GERBIL_PATH']=str(SNAP/'.gerbil');env['GERBIL_LOADPATH']=str(SNAP/'.gerbil/lib');env['LIBRARY_PATH']=subprocess.check_output(['brew','--prefix','openssl@3'],text=True).strip()+'/lib'
  for k in ('CC','CFLAGS','CPPFLAGS','LDFLAGS','CPATH','C_INCLUDE_PATH','CPLUS_INCLUDE_PATH','NIX_CFLAGS_COMPILE','NIX_LDFLAGS','DEVELOPER_DIR','SDKROOT'):env.pop(k,None)
  self.err=(BASE/'native-stderr.log').open('a');self.p=subprocess.Popen([str(SNAP/'.gerbil/bin/factor-pilot'),'-:max-heap=1G,debug=q'],cwd=SNAP,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
 def call(self,**kw):
  began=time.monotonic();self.p.stdin.write(json.dumps(kw)+'\n');self.p.stdin.flush()
  s=selectors.DefaultSelector();s.register(self.p.stdout,selectors.EVENT_READ)
  if not s.select(20):self.close();raise TimeoutError('native reply deadline')
  s.close();line=self.p.stdout.readline()
  if not line:raise RuntimeError('native exited; see native-stderr.log')
  r=json.loads(line)
  if 'error' in r:raise RuntimeError(r['error'])
  return r,time.monotonic()-began
 def close(self):
  if self.p.poll() is None:
   self.p.terminate()
   try:self.p.wait(timeout=5)
   except subprocess.TimeoutExpired:self.p.kill();self.p.wait(timeout=5)
  self.err.close()
CASES=[{'id':'fork','edges':[[0,2],[1,2],[2,4],[1,3],[3,5],[4,6],[5,6]],'durations':[3,2,4,1,3,2,1],'weights':[[2,1,4,2,1,3],[1,5,1,3,4,2,8]]},
       {'id':'diamond','edges':[[0,2],[0,3],[1,3],[2,4],[3,4],[3,5],[4,6]],'durations':[2,4,1,3,2,1,3],'weights':[[1,3,2,4,1,2],[5,1,4,1,3,7,2]]}]
TOOLS=[{'type':'function','name':name,'description':desc,'parameters':{'type':'object','properties':props,'required':list(props),'additionalProperties':False}} for name,desc,props in [
 ('factor','Check whether precedence u -> v is implied by the source graph; true facts must hold in schedules.',{'u':{'type':'integer'},'v':{'type':'integer'}}),
 ('evaluate','Check a full schedule and return weighted completion cost; lower is better.',{'order':{'type':'array','items':{'type':'integer'}}}),
 ('explore','Check a partial schedule and list feasible next jobs.',{'prefix':{'type':'array','items':{'type':'integer'}}}),
 ('submit','Submit your best full schedule and finish the phase.',{'order':{'type':'array','items':{'type':'integer'}}})]]
INSTRUCTIONS='You solve finite scheduling optimization. Minimize sum(weight[j]*completion_time[j]) on a single machine without idle time. All jobs appear once and every implied precedence must hold. Use factor to resolve shared deterministic factors, explore to investigate branches, and evaluate to compare candidate schedules. Finish with submit. You have at most 6 response calls, 24 tool actions and 24576 total output tokens including reasoning per phase. Do not access hidden grading. Some tool replies include retained facts or checked fragments; use them if useful. Cached evidence is confined to the same source digest. Optimize deeply within the budget.'
def freeze():
 plan={'frozenAtUtc':datetime.now(timezone.utc).isoformat(),'schema':'ascent.factor-reuse-real-pilot.v2','supersedesCensoredPilot':'censored-2048/frozen-plan.json','revisionReason':'All 16 v1 phases exhausted the 2048 per-call output cap entirely in reasoning before any tool action. Preserve v1 separately; raise equal phase allowance to 24576 and per-call cap to 16384 for all arms; same tasks/grader.','model':'deepseek-flash','reasoningEffort':'high','arms':{'A':'fresh checked atomic factors','B':'retained cards without independent proof gate','C':'checked retained atomic factors','D':'checked shared closure and derivation DAG'},'cases':CASES,'phaseOutputBudget':24576,'perCallOutputCap':16384,'phaseCallLimit':6,'phaseToolLimit':24,'replicates':1,'order':[{'case':c['id'],'arm':a} for ci,c in enumerate(CASES) for a in (list('ABCD') if ci==0 else list('DCBA'))],'instructions':INSTRUCTIONS,'tools':TOOLS,'grader':'t/research/factor-pilot.ss direct-edge permutation enumeration; no model grader','hiddenThinkingMeasurement':False,'taskScope':'Controlled transfer after history reset, 6 jobs then 7 jobs; precedence sources unchanged; weights/goals change. No full-answer cache.','failurePolicy':'No retries. Retain failed/incomplete calls, invalid schedules, missing usage and censored phases.','buildScope':'Frozen current Scheme production modules excluding applications/domain-evidence, interface/engine-api and interface/c-api after full-build syntax failure. This is not full build qualification.','costPolicy':'All input/output including reasoning charged. Native admission+proof storage+IO recorded. Native cache resets per trajectory. Cold phase included. USD invoice unavailable.'}
 paths=['t/research/factor-pilot.ss','t/research/factor-pilot-build.ss','packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/factor_pilot.py','packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py','packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py','rust/ascent/src/conversation.rs']
 runtime=Path(shutil.which('gxi')).resolve();plan['runtime']={'path':str(runtime),'sha256':sha(runtime.read_bytes())}
 plan['qualificationSha256']=sha((BASE/'qualification.json').read_bytes())
 plan['formalReceipts']={p:sha((BASE/p).read_bytes()) for p in ('native-retained-correspondence.json','quint-retained-correspondence.json','lean-native-quint-correspondence.log','lean-retained.log','quint-retained.log')}
 plan['producerHashes']={p:sha((ROOT/p).read_bytes()) for p in paths}
 # Bind every fresh compiler output and retained dependency byte, not pre-existing ASCENT objects.
 plan['artifactHashes']={str(p.relative_to(SNAP)):sha(p.read_bytes()) for p in (SNAP/'.gerbil/lib').rglob('*') if p.is_file() and not p.name.endswith('.lock')}
 plan['artifactHashes']['.gerbil/bin/factor-pilot']=sha((SNAP/'.gerbil/bin/factor-pilot').read_bytes())
 plan['scopedBuildHash']=sha((SNAP/'build.ss').read_bytes());plan['sourceManifestHash']=sha((BASE/'source-manifest.json').read_bytes())
 save(BASE/'frozen-plan.json',plan);(BASE/'frozen-plan.sha256').write_text(sha((BASE/'frozen-plan.json').read_bytes())+'\n')
 return plan
def qualification():
 native=SchemeEngine();obs=[]
 try:
  native.call(op='init',arm='A',edges=[],identity='oracle-control')
  control,_=native.call(op='grade',durations=[1,2,3],weights=[3,2,1],order=[0,1,2])
  assert control['oracle']=={'optimum':15,'feasibleOrders':6,'enumeratedOrders':6} and control['optimal']
  native.call(op='init',arm='A',edges=[[0,1],[1,2]],identity='chain-control')
  chain,_=native.call(op='grade',durations=[1,2,3],weights=[3,2,1],order=[0,1,2])
  prefix,_=native.call(op='explore',prefix=[1],n=3)
  assert chain['oracle']['feasibleOrders']==1 and not prefix['validPrefix']
  for c in CASES:
   for a in 'ABCD':
    native.call(op='init',arm=a,edges=c['edges'],identity=c['id'])
    x,_=native.call(op='factor',u=0,v=4);y,_=native.call(op='factor',u=0,v=4);z,_=native.call(op='factor',u=1,v=5)
    assert x['precedes'] and x['freshNativeSolve'] and y['reused']==(a!='A')
    assert z['precedes'] and z['reused']==(a=='D')
    f,_=native.call(op='fault');assert all(f.values())
    for phase in range(2):
     n=6+phase;ds=c['durations'][:n];ws=c['weights'][phase]
     gold,_=native.call(op='grade',durations=ds,weights=ws,order=list(range(n)))
     bad,_=native.call(op='grade',durations=ds,weights=ws,order=list(reversed(range(n))))
     assert gold['valid'] and not bad['valid'] and gold['oracle']['enumeratedOrders'] in (720,5040)
     obs.append({'case':c['id'],'arm':a,'phase':phase,'grade':gold,'faults':f})
  correspondence=[]
  for ident in range(16):
   for phase in range(2):
    current=ident-4 if phase==1 and ident&4 else ident
    graph=[e for i,e in enumerate([[0,0],[0,1],[1,0],[1,1]]) if current&(1<<i)]
    native.call(op='init',arm='C',edges=graph,identity=f'finite-{current}')
    x,_=native.call(op='factor',u=0,v=0);y,_=native.call(op='factor',u=1,v=0)
    # Python only projects native boolean observations into the model wire mask.
    correspondence.append([ident,phase,current,int(x['precedes'])+2*int(y['precedes']),int(ident==current)])
  save(BASE/'native-retained-correspondence.json',correspondence)
  save(BASE/'qualification.json',{'passed':True,'observations':obs});print('QUALIFICATION-OK',len(obs),flush=True)
 finally:native.close()
def question(c,phase,cards):
 n=6+phase
 return json.dumps({'task':c['id'],'phase':phase,'jobs':list(range(n)),'durations':c['durations'][:n],'weights':c['weights'][phase],'sourceEdges':c['edges'],'sourceIdentity':c['id'],'retained':cards,'guidance':'This objective differs from prior phases. Check useful implied precedence factors (especially nonadjacent jobs) once and reuse supported evidence. Compare several feasible schedules. Submit best found.'},sort_keys=True)
def run(plan):
 expected=(BASE/'frozen-plan.sha256').read_text().strip();assert sha((BASE/'frozen-plan.json').read_bytes())==expected
 assert sha(Path(plan['runtime']['path']).read_bytes())==plan['runtime']['sha256']
 for p,h in plan['producerHashes'].items():assert sha((ROOT/p).read_bytes())==h,p
 for p,h in plan['artifactHashes'].items():assert sha((SNAP/p).read_bytes())==h,p
 assert sha((SNAP/'t/research/factor-pilot.ss').read_bytes())==plan['producerHashes']['t/research/factor-pilot.ss']
 assert sha((BASE/'qualification.json').read_bytes())==plan['qualificationSha256']
 for p,h in plan['formalReceipts'].items():assert sha((BASE/p).read_bytes())==h,p
 assert 'RETAINED-INFERENCE-LEAN-OK observations=32' in (BASE/'lean-native-quint-correspondence.log').read_text()
 assert json.loads((BASE/'qualification.json').read_text())['passed']
 key=provider_key();paid=BASE/'paid';paid.mkdir(exist_ok=False);records=[]
 for item in plan['order']:
  c=next(c for c in plan['cases'] if c['id']==item['case']);arm=item['arm'];began=time.monotonic();native=SchemeEngine();init,_=native.call(op='init',arm=arm,edges=c['edges'],identity=c['id']);startup=time.monotonic()-began
  seen=set()
  try:
   for phase in range(2):
    folder=paid/f'{c["id"]}-{arm}-{phase}';folder.mkdir();store=folder/'proof-store';store.mkdir()
    cards,card_seconds=native.call(op='cards') if arm!='A' else ({},0)
    history=ResponseHistory(question(c,phase,cards));n=6+phase;ds=c['durations'][:n];ws=c['weights'][phase];row={**item,'phase':phase,'calls':[],'tools':[],'grade':None,'failure':None,'budget':24576,'nativeStartupAndInitSeconds':startup if phase==0 else 0,'cardsReadSeconds':card_seconds};used=0;tool_count=0;best=None;submitted=None
    for turn in range(6):
     if used>=24576 or tool_count>=24:row['failure']='phase_budget_exhausted';break
     request={'model':plan['model'],'input':history.input(),'instructions':plan['instructions'],'tools':TOOLS,'tool_choice':'auto','reasoning':{'effort':'high'},'max_output_tokens':min(plan['perCallOutputCap'],24576-used),'stream':True,'store':False}
     save(folder/f'{turn}.request.json',request)
     raw,meta=provider(request,key,folder/f'{turn}.response.json');terminal=meta.get('terminal') or {};usage=terminal.get('usage');call={'turn':turn,'usage':usage,'seconds':meta['providerSeconds'],'outcome':response_outcome(meta),'rawFile':str((folder/f'{turn}.response.json').relative_to(BASE))};row['calls'].append(call)
     save(folder/'receipt.json',row)
     if isinstance(usage,dict) and isinstance(usage.get('output_tokens'),int):used+=usage['output_tokens']
     if meta.get('error') or terminal.get('status')!='completed':row['failure']=call['outcome'];break
     if not isinstance(usage,dict) or not isinstance(usage.get('output_tokens'),int):row['failure']='missing_usage_budget_unknown';break
     try:calls=history.append_response(terminal)
     except Exception as e:row['failure']='invalid_conversation:'+str(e);break
     if not calls:row['failure']='no_submit';break
     for fc in calls:
      name=fc['name'];tool_count+=1;started=time.monotonic();log={'name':name,'rawArguments':fc['arguments']}
      args={}
      try:
       args=json.loads(fc['arguments']);log['arguments']=args
       if tool_count>24:result={'error':'tool budget exhausted'}
       elif name=='factor':
        result,ipc=native.call(op='factor',**args);k=(args['u'],args['v']);log['repeatRequest']=k in seen;seen.add(k);log['nativeRoundtripSeconds']=ipc
        certificate=result.pop('admittedCertificate',None)
        if certificate:
         payload=json.dumps(certificate,sort_keys=True).encode();h=sha(payload);(store/f'{h}.json').write_bytes(payload);log['proofStoreSha256']=h;log['proofStoreBytes']=len(payload)
         # D exposes bounded shared derivation structure; others same atomic answer.
         if arm=='D':result['derivationDAG']=certificate
        log['factorReceipt']=result
       elif name in ('evaluate','submit'):
        result,_=native.call(op='evaluate',durations=ds,weights=ws,**args)
        if result['valid'] and (best is None or result['objective']<best[0]):best=(result['objective'],args['order'])
        if name=='submit':submitted=args['order']
       elif name=='explore':result,_=native.call(op='explore',n=n,**args)
       else:raise ValueError('unknown tool')
      except Exception as e:result={'error':str(e)[:2000]};log['failure']=str(e)[:2000]
      log['result']=result;log['totalToolSeconds']=time.monotonic()-started;row['tools'].append(log);history.append_result(fc['call_id'],result)
     save(folder/'receipt.json',row)
     if submitted is not None:break
    candidate=submitted if submitted is not None else (best[1] if best else [])
    row['submitted']=submitted is not None;row['candidate']=candidate;row['observedOutputTokens']=used
    row['grade'],seconds=native.call(op='grade',durations=ds,weights=ws,order=candidate);row['graderSeconds']=seconds
    if not row['submitted'] and not row['failure']:row['failure']='call_budget_exhausted'
    save(folder/'receipt.json',row);records.append(row);save(paid/'records.json',records)
    print('\nPHASE',c['id'],arm,phase,'calls',len(row['calls']),'output',used,'grade',row['grade'],'failure',row['failure'],flush=True)
  finally:native.close()
 return records
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('command',choices=['qualify','freeze','run']);args=parser.parse_args()
 if args.command=='qualify':qualification()
 elif args.command=='freeze':p=freeze();print('FROZEN',len(p['artifactHashes']))
 else:run(json.loads((BASE/'frozen-plan.json').read_text()))
