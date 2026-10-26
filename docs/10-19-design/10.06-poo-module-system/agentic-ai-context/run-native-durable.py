#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Real native owner process death, SQLite recovery and replay evidence gate."""
import argparse, hashlib, importlib.util, itertools, json, os, re, selectors, signal, sqlite3, subprocess, sys, tempfile, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('clock_gate',HERE/'run-native-clock.py');clock=importlib.util.module_from_spec(spec);spec.loader.exec_module(clock)
ROOT=clock.ROOT;base=clock.base
# The durable driver imports native fixture factories directly. It never loads
# the standalone suite-selection registry specialized.ss. The separate live
# clock gate still binds that registry in its own receipt.
INPUTS=tuple(p for p in dict.fromkeys((*clock.INPUTS,
 'modules/temporal-causality/runtime/durable-journal.ss','modules/ai-agentic-context/durable-owner.ss',
 't/context-durable-owner.ss','t/harness/context-durable-driver.ss','build.ss',
 str(Path(__file__).resolve().relative_to(ROOT))))
 if p!='t/qualification/testing/specialized.ss')
STAGES=('after-receive','before-commit','after-commit')
ALL=clock.ALL
# Explicit native crash sample. The complete 60-order live-owner corpus is a
# separate gate; these distinct prefixes exercise the durable publication cuts.
CRITICAL=[(1,2,3,4,5),(2,1,3,4,5),(3,1,2,4,5),(4,1,2,3,5),
 (4,5,1,2,3),(2,3,4,5,1),(3,2,4,5,1),(4,2,3,5,1),
 (4,5,2,3,1),(4,3,5,2,1)]
BAD=re.compile(r'ERROR CASE|ERROR CHECK|ERROR HARNESS|ERROR MODULE|Heap overflow|Stack overflow|undefined\n')

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def binaries():
 r=clock.binaries()
 paths=['modules/ai-agentic-context/session-host','modules/ai-agentic-context/use-host','modules/ai-agentic-context/durable-owner',
  'modules/temporal-causality/evaluator/proof-host','modules/temporal-causality/truth-maintenance/support/policy-host',
  'modules/temporal-causality/runtime/durable-journal','t/temporal-evaluator-test','t/context-durable-owner']
 for name in paths:
  stem=ROOT/'.gerbil/lib/agentic-ai-lab'/name
  for p in stem.parent.glob(stem.name+'*'):
   if p.is_file() and (re.search(r'\.o[0-9]+$',p.name) or p.suffix=='.ssi' or p.name.endswith('.ssxi.ss')):r[str(p.relative_to(ROOT))]=sha(p)
  if any(stem.parent.glob(stem.name+'~0.o[2-9]*')):raise RuntimeError('Stale higher native object shadows fresh build')
 return r

def command(db,mode,order,stage,profile):
 return ['just','test-context-durable-worker',str(db),mode,'('+' '.join(map(str,order))+')',stage,profile]

def kill_owned(p):
 if p.poll() is None:
  os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=10)

def held_process(folder,order,stage,profile,env):
 p=subprocess.Popen(command(folder/'journal.sqlite','pre',order,stage,profile),cwd=ROOT,env=env,
  stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0,start_new_session=True,stdin=subprocess.PIPE)
 sel=selectors.DefaultSelector();sel.register(p.stdout,selectors.EVENT_READ);started=time.monotonic()
 log=folder/'pre.log';held=False;buffer=b''
 with log.open('wb') as out:
  while time.monotonic()-started<95:
   if sel.select(1):
    chunk=os.read(p.stdout.fileno(),65536)
    if not chunk:break
    out.write(chunk);out.flush();buffer+=chunk
    while b'\n' in buffer:
     line,buffer=buffer.split(b'\n',1)
     if line.startswith(b'DURABLE-HELD '):held=True;break
    if held:break
  if not held:
   kill_owned(p)
   raise RuntimeError(f'Native owner failed before crash window: {log}')
 return p

def db_summary(path):
 with sqlite3.connect(path) as db:
  if db.execute('PRAGMA integrity_check').fetchone()!=('ok',):raise RuntimeError('SQLite recovery integrity failure')
  if db.execute('PRAGMA journal_mode').fetchone()[0].lower()!='wal':raise RuntimeError('Not SQLite WAL')
  for table in ('state','evidence','inbox','versions','terminals'):
   for payload,digest in db.execute(f'SELECT payload,digest FROM {table}'):
    if 'sha256:'+hashlib.sha256(payload.encode()).hexdigest()!=digest:raise RuntimeError('Persisted payload digest mismatch')
  if db.execute('SELECT count(*) FROM (SELECT session,attempt,generation,count(*) AS n FROM terminals GROUP BY 1,2,3 HAVING n>1)').fetchone()[0]:raise RuntimeError('Duplicate terminal')
  return {'epoch':db.execute('SELECT epoch FROM owner').fetchone()[0],
   'originals':dict(db.execute('SELECT k,digest FROM evidence')),
   'old_terminals':db.execute("SELECT count(*) FROM terminals WHERE session='session'").fetchone()[0],
   'terminal_digests':dict(db.execute("SELECT session||':'||attempt||':'||generation,digest FROM terminals")),
   'versions':db.execute('SELECT count(*) FROM versions').fetchone()[0],
   'decisions':db.execute('SELECT count(*) FROM log').fetchone()[0],
   'pending':db.execute("SELECT count(*) FROM inbox WHERE status='pending'").fetchone()[0]}

def post(folder,order,stage,profile,env):
 log=folder/'post.log'
 with log.open('w') as out:
  p=subprocess.Popen(command(folder/'journal.sqlite','post',order,stage,profile),cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
  try:p.wait(timeout=95)
  except subprocess.TimeoutExpired:kill_owned(p);raise
 text=log.read_text();lines=text.splitlines()
 if p.returncode or BAD.search(text) or not all(m in lines for m in ('MODULE-OK t/context-durable-owner.ss','HARNESS-OK context-durable-owner','OK')):
  raise RuntimeError(f'Native restart/harness failed: {log}')
 recover=re.findall(r'^DURABLE-RECOVER epoch=([0-9]+) old-terminal-count=([01]) old-current=#f pending-preserved=#t new-completed=#t source-retained=#t chain=(sha256:[0-9a-f]{64})$',text,re.M)
 if len(recover)!=1 or 'DURABLE-ORG same-id-different-source=rejected exact-query-replay=#t' not in lines or 'DURABLE-CALENDAR replacement-ticket-retained=#t' not in lines:
  raise RuntimeError('Missing native recovery/Org contract evidence')
 proofs=re.findall(r'^NATIVE-CLOCK-EVIDENCE journal=(sha256:[0-9a-f]{64}) proof=(sha256:[0-9a-f]{64}) event=(sha256:[0-9a-f]{64}) context-index=(sha256:[0-9a-f]{64})$',text,re.M)
 if len(proofs)!=1:raise RuntimeError('Missing original ASCENT/journal propagation evidence')
 return {'epoch':int(recover[0][0]),'old_terminals':int(recover[0][1]),'chain':recover[0][2],
   'original_proof':proofs[0][1],'source_journal':proofs[0][0],'propagation_event':proofs[0][2],'context_index':proofs[0][3]}

def case(folder,order,stage,profile,env):
 folder.mkdir(parents=True,exist_ok=False)
 p=held_process(folder,order,stage,profile,env)
 kill_owned(p)
 if p.returncode!=-signal.SIGKILL:raise RuntimeError('Owner was not killed by SIGKILL')
 before=db_summary(folder/'journal.sqlite')
 expected=int(profile=='terminal' and stage=='after-commit')
 if before['old_terminals']!=expected:raise RuntimeError('Wrong pre-restart durable terminal boundary')
 # Preserve the actual committed crash image for every cut, not only the
 # missed-send fixture. The new owner never mutates this independent backup.
 with sqlite3.connect(folder/'journal.sqlite') as src,sqlite3.connect(folder/'crash.sqlite') as dst:src.backup(dst)
 if db_summary(folder/'crash.sqlite')!=before:raise RuntimeError('Crash backup differs from killed owner state')
 if profile=='terminal':time.sleep(3.05)
 actual=post(folder,order,stage,profile,env);after=db_summary(folder/'journal.sqlite')
 if after['epoch']!=before['epoch']+1 or actual['epoch']!=after['epoch'] or actual['old_terminals']!=expected or after['old_terminals']!=expected or before['originals']!=after['originals']:
  raise RuntimeError('Owner epoch, evidence or terminal changed incorrectly')
 if any(after['terminal_digests'].get(k)!=v for k,v in before['terminal_digests'].items()):raise RuntimeError('Committed terminal rewritten')
 row={'order':list(order),'stage':stage,'profile':profile,'signal':p.returncode,'before':before,'after':after,'native':actual,
      'pre_log_sha256':sha(folder/'pre.log'),'post_log_sha256':sha(folder/'post.log'),'crash_sha256':sha(folder/'crash.sqlite')}
 (folder/'case.json').write_text(json.dumps(row,indent=2)+'\n')
 return row

def native_controls(out,env,source_case):
 controls=[]
 # Each counterexample starts from the real missed-send crash, not a finite model.
 for name,mode,marker in (
  ('no-rearm','counter-no-rearm','DURABLE-COUNTEREXAMPLE no-rearm-after-restart cached-admitted=#t automatic-invalidation=#f'),
  ('stale-handler','counter-stale','DURABLE-COUNTEREXAMPLE stale-handler-rebases-old-policy new-context-invalidated=#t')):
  folder=out/('counter-'+name);folder.mkdir()
  with sqlite3.connect(source_case/'crash.sqlite') as source,sqlite3.connect(folder/'journal.sqlite') as dest:source.backup(dest)
  log=folder/'counter.log'
  with log.open('w') as stream:
   p=subprocess.Popen(command(folder/'journal.sqlite',mode,ALL[0],STAGES[0],'missed'),cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
   try:p.wait(timeout=95)
   except subprocess.TimeoutExpired:kill_owned(p);raise
  text=log.read_text()
  if p.returncode or marker not in text.splitlines() or BAD.search(text):raise RuntimeError('Native counterexample missing: '+str(log))
  controls.append({'name':name,'marker':marker,'log':str(log.relative_to(out)),'sha256':sha(log)})
 # Old owner remains alive while the new owner claims the durable epoch.
 folder=out/'stale-owner';folder.mkdir()
 fence_env=dict(env,CONTEXT_EXPECT_OWNER_FENCE='1')
 p=held_process(folder,(1,2,3,4,5),'after-receive','tickets',fence_env)
 try:
  with (folder/'claim.log').open('w') as stream:
   subprocess.run(command(folder/'journal.sqlite','claim',ALL[0],'after-receive','tickets'),cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=30,check=True)
  p.stdin.write(b'resume\n');p.stdin.flush()
  try:p.wait(timeout=20)
  except subprocess.TimeoutExpired:kill_owned(p);raise
  rest=p.stdout.read()
  with (folder/'pre.log').open('ab') as stream:stream.write(rest)
  text=(folder/'pre.log').read_text()
  if p.returncode or 'DURABLE-FENCED stale-owner-native-decision-refused=#t' not in text.splitlines():raise RuntimeError('Stale live owner was not fenced')
  actual=post(folder,ALL[0],'after-receive','tickets',env)
  controls.append({'name':'stale-live-owner','log':str((folder/'pre.log').relative_to(out)),'sha256':sha(folder/'pre.log'),'new_epoch':actual['epoch'],'max_gerbil_processes':2,'aggregate_heap_budget':'2G'})
 finally:kill_owned(p)
 return controls

def verify_receipt(path):
 r=json.loads(path.read_text());folder=path.parent
 if sha(folder/'start-cut.json')!=r['start_cut_sha256']:raise RuntimeError('Initial runtime cut commitment changed')
 if r['schema']!='context.native-durable.v1' or set(r['source_sha256'])!=set(INPUTS) or any(sha(ROOT/k)!=v for k,v in r['source_sha256'].items()) or r['binaries']!=binaries() or r['ascent_head']!=base.ascent_revision(ROOT) or r['orgize_head']!=base.orgize_revision(ROOT):raise RuntimeError('Durable source/binary cut is stale')
 for control in r['controls']:
  if sha(folder/control['log'])!=control['sha256']:raise RuntimeError('Native control log changed')
 for row in r['cases']:
  d=folder/row['folder']
  if sha(d/'crash.sqlite')!=row['crash_sha256'] or db_summary(d/'crash.sqlite')!=row['before']:raise RuntimeError('Committed crash image changed')
  if sha(d/'pre.log')!=row['pre_log_sha256'] or sha(d/'post.log')!=row['post_log_sha256'] or db_summary(d/'journal.sqlite')!=row['after']:raise RuntimeError('Durable case artifact changed')
  text=(d/'post.log').read_text()
  if BAD.search(text) or not all(m in text.splitlines() for m in ('MODULE-OK t/context-durable-owner.ss','HARNESS-OK context-durable-owner','OK')):raise RuntimeError('Missing native recovery markers')
  if row['signal']!=-9 or row['native']['old_terminals']!=int(row['profile']=='terminal' and row['stage']=='after-commit'):raise RuntimeError('Wrong saved crash outcome')
 if r['mode']=='all' and [(tuple(x['order']),x['stage'],x['profile']) for x in r['cases']]!=[(o,t,'tickets') for t in STAGES for o in ALL]+[(ALL[0],t,'terminal') for t in STAGES]+[(ALL[0],STAGES[0],'missed')]:raise RuntimeError('Incomplete saved crash corpus')
 if r['mode']=='critical' and [(tuple(x['order']),x['stage'],x['profile']) for x in r['cases']]!=[(o,t,'tickets') for t in STAGES for o in CRITICAL]+[(CRITICAL[0],t,'terminal') for t in STAGES]+[(CRITICAL[0],STAGES[0],'missed')]:raise RuntimeError('Incomplete critical crash corpus')
 return r

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',type=Path);p.add_argument('--order');p.add_argument('--corpus',choices=('all','critical'),default='all');p.add_argument('--stage',choices=STAGES);p.add_argument('--skip-build',action='store_true');p.add_argument('--check-receipt',type=Path);p.add_argument('--reuse-build',type=Path);p.add_argument('--replay-crash',type=Path,help='Verified receipt whose preserved crash image is recovered again');p.add_argument('--case-index',type=int,default=0);p.add_argument('--jobs',type=int,choices=(1,2),default=1,help='At most two 1 GiB Gerbil workers; controls run after all cases join');a=p.parse_args()
 if a.check_receipt:
  r=verify_receipt(a.check_receipt);print(f'CURRENT DURABLE RECEIPT: {len(r["cases"])} real crash/restart cases; {a.check_receipt}');return
 out=a.artifacts or Path(tempfile.mkdtemp(prefix='context-durable-',dir='/private/tmp'));out.mkdir(parents=True,exist_ok=True)
 orders=(ALL if a.corpus=='all' else CRITICAL) if not a.order else [tuple(map(int,a.order.split(',')))]
 if not all(o in ALL for o in orders):raise RuntimeError('Illegal native durable replay')
 stages=STAGES if not a.stage else (a.stage,)
 source={name:sha(ROOT/name) for name in INPUTS};ascent=base.ascent_revision(ROOT);orgize=base.orgize_revision(ROOT)
 env=os.environ.copy()
 for name in tuple(env):
  if name.startswith('AGENTIC_CONTEXT_'):env.pop(name)
 env.update(GERBIL_PATH=str(ROOT/'.gerbil'),GERBIL_LOADPATH=f'{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib')
 if a.replay_crash:
  prior=verify_receipt(a.replay_crash)
  if (out/'journal.sqlite').exists():raise RuntimeError('Crash replay destination already exists')
  if not 0<=a.case_index<len(prior['cases']):raise RuntimeError('Invalid crash replay index')
  row=prior['cases'][a.case_index];original=a.replay_crash.parent/row['folder']/'crash.sqlite'
  with sqlite3.connect(original) as src,sqlite3.connect(out/'journal.sqlite') as dst:src.backup(dst)
  if db_summary(out/'journal.sqlite')!=row['before']:raise RuntimeError('Replay crash input differs')
  actual=post(out,tuple(row['order']),row['stage'],row['profile'],env)
  if actual['epoch']!=row['before']['epoch']+1 or actual['old_terminals']!=row['native']['old_terminals'] or any(actual[k]!=row['native'][k] for k in ('original_proof','source_journal')):raise RuntimeError('Original crash replay violated recovery invariants')
  verify_receipt(a.replay_crash)
  (out/'crash-replay.json').write_text(json.dumps({'schema':'context.crash-image-replay.v1','receipt_sha256':sha(a.replay_crash),'case_index':a.case_index,'crash_sha256':sha(original),'source_sha256':source,'binaries':binaries(),'actual':actual,'after':db_summary(out/'journal.sqlite'),'post_log_sha256':sha(out/'post.log'),'scope':'same committed crash image; new real clock observations and decisions'},indent=2)+'\n')
  print(f'PASS: original committed crash image replay {a.case_index}; {out}',flush=True);return
 if a.reuse_build:verify_receipt(a.reuse_build)
 if not a.skip_build and not a.reuse_build:
  with (out/'build.log').open('w') as stream:subprocess.run(['just','build-test', 't/context-durable-owner.ss'],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=600,check=True)
 binary=binaries();rows=[]
 (out/'start-cut.json').write_text(json.dumps({'source_sha256':source,'binaries':binary,'ascent_head':ascent,'orgize_head':orgize},indent=2)+'\n')
 jobs=[(o,s,'tickets') for s in stages for o in orders]+[(orders[0],s,'terminal') for s in stages]+[(orders[0],stages[0],'missed')]
 def run_case(job):
  n,(order,stage,profile)=job
  folder=out/f'{n:03d}-{profile}-{stage}'
  row=case(folder,order,stage,profile,env);row['folder']=folder.name
  print(f'CASE-OK durable {n}/{len(jobs)} profile={profile} stage={stage} order={order}',flush=True)
  return row
 # This is the aggregate memory scheduler: each case has only one live native
 # process at a time, each Just entrypoint is fenced at 1 GiB. No controls or
 # additional native suites overlap this pool. Default execution remains serial.
 with ThreadPoolExecutor(max_workers=a.jobs) as pool:rows=list(pool.map(run_case,enumerate(jobs,1)))
 controls=native_controls(out,env,out/rows[-1]['folder'])
 changed_sources=[name for name in INPUTS if source[name]!=sha(ROOT/name)]
 now_binary=binaries();changed_objects=[name for name in set(binary)|set(now_binary) if binary.get(name)!=now_binary.get(name)]
 if changed_sources or changed_objects or ascent!=base.ascent_revision(ROOT) or orgize!=base.orgize_revision(ROOT):raise RuntimeError(f'Runtime cut changed; sources={changed_sources}; objects={changed_objects}; partial logs remain unqualified')
 receipt={'schema':'context.native-durable.v1','mode':a.corpus if not a.order and not a.stage else 'replay','cases':rows,'controls':controls,'source_sha256':source,'binaries':binary,'ascent_head':ascent,'orgize_head':orgize,'start_cut_sha256':sha(out/'start-cut.json'),
  'scope':{'real_sigkill':True,'real_sqlite_wal':True,'same_boot_monotonic_recovery':True,'all_owner_machine_schedules':False,'power_failure':False,'distributed_provider_exactly_once':False,'case_jobs':a.jobs,'max_concurrent_gerbil_processes':2,'aggregate_heap_budget':'2G','heap_per_process':'1G'}}
 (out/'durable-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(f'PASS: {len(rows)} actual SIGKILL/restart cases; {out}',flush=True)
if __name__=='__main__':
 try:main()
 except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as e:print('ERROR: '+str(e),file=sys.stderr);sys.exit(1)
