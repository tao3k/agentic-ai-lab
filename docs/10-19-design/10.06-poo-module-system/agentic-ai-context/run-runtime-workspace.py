#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Process/artifact gate over the existing Durable owner; no recovery reducer."""
import argparse, hashlib, importlib.util, json, os, selectors, shutil, signal, sqlite3, subprocess, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location('existing_durable', HERE/'run-runtime-durable.py')
durable = importlib.util.module_from_spec(spec); spec.loader.exec_module(durable)
INPUTS = (
 'modules/ai-agentic-context/durable-owner.ss', 'modules/ai-agentic-context/recovery-observation.ss',
 'modules/ai-agentic-context/session-host.ss', 'modules/session/funs-attempt.ss',
 'modules/temporal-causality/runtime/durable-journal.ss', 'modules/temporal-causality/runtime/policy-clock.ss',
 't/harness/context-workspace-driver.ss', 't/context-query-provider-test.ss',
 't/context-query-durable-test.ss', 't/temporal-evaluator-test.ss', 'dev/just/runtime-tests.just',
 str(Path(__file__).resolve().relative_to(ROOT)))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def runtime_binaries():
 result=durable.binaries()
 for name in ('recovery-observation','query-provider'):
  stem=ROOT/'.gerbil/lib/agentic-ai-lab/modules/ai-agentic-context'/name
  for p in stem.parent.glob(stem.name+'*'):
   if p.is_file() and (p.suffix=='.o1' or p.suffix=='.ssi' or p.name.endswith('.ssxi.ss')):
    result[str(p.relative_to(ROOT))]=sha(p)
  if any(stem.parent.glob(stem.name+'~0.o[2-9]*')):raise RuntimeError('Stale higher recovery object')
 return result
def run(folder, phase):
 folder.mkdir(parents=True, exist_ok=False)
 root = folder/'workspace'; root.mkdir(mode=0o700)
 target = root/'notes.txt'; target.write_text('First line.\n')
 with target.open('rb') as f: os.fsync(f.fileno())
 db = folder/'journal.sqlite'
 source = {p:sha(ROOT/p) for p in INPUTS}
 binary_cut = runtime_binaries()
 command = ['just','test-context-workspace',str(db),str(root),'pre',phase]
 env = os.environ.copy()
 process = subprocess.Popen(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                            stdin=subprocess.PIPE,start_new_session=True,bufsize=0)
 held=False; data=b''; start=time.monotonic(); sel=selectors.DefaultSelector();sel.register(process.stdout,selectors.EVENT_READ)
 try:
  with (folder/'pre.log').open('wb') as log:
   while time.monotonic()-start<100:
    if sel.select(1):
     chunk=os.read(process.stdout.fileno(),65536)
     if not chunk: break
     log.write(chunk);log.flush();data+=chunk
     if b'WORKSPACE-HELD '+phase.encode()+b' worker-terminal=1\n' in data:
      held=True;break
   if not held: raise RuntimeError('Owner did not reach the actual result publication cut; inspect pre.log')
   if target.read_bytes()!=b'First line.\nAdded line.\n': raise RuntimeError('Runtime worker did not modify the workspace')
   calls=Path(str(db)+'.calls')
   if calls.read_text().splitlines()!=['workspace-edit']: raise RuntimeError('Unexpected effect invocation count')
   # Read-only independent flush after the worker closed the file. No receipt,
   # result or workspace bytes are manufactured by the process controller.
   for p in (target,calls):
    with p.open('rb') as f: os.fsync(f.fileno())
   fd=os.open(root,os.O_RDONLY)
   try: os.fsync(fd)
   finally: os.close(fd)
   os.killpg(process.pid,signal.SIGKILL);code=process.wait(timeout=10)
   if code!=-signal.SIGKILL: raise RuntimeError('The owned process did not die by SIGKILL')
  image=folder/'crash-image';image.mkdir()
  for suffix in ('','-wal','-shm'):
   p=Path(str(db)+suffix)
   if p.exists(): shutil.copy2(p,image/p.name)
  shutil.copy2(target,image/'notes.txt');shutil.copy2(calls,image/'calls')
  summary=durable.db_summary(db)
  with sqlite3.connect(db) as connection:
   terminals=connection.execute('SELECT count(*) FROM terminals').fetchone()[0]
   result_status=connection.execute("SELECT status FROM inbox WHERE id='workspace-result'").fetchone()[0]
  wanted=0 if phase=='before-commit' else 1
  if terminals!=wanted or result_status!=('pending' if wanted==0 else 'applied'):
   raise RuntimeError('Committed ledger differs from the selected actual publication cut')
  if source!={p:sha(ROOT/p) for p in INPUTS}: raise RuntimeError('Runtime sources changed during qualification')
  if binary_cut!=runtime_binaries(): raise RuntimeError('Runtime binary cohort changed during qualification')
  receipt={'schema':'context.workspace-crash.v1','phase':phase,'exitCode':code,'workerInvocations':1,
           'workspace':str(root),'database':str(db),'contentSHA256':sha(target),'terminals':terminals,
           'resultStatus':result_status,'sources':source,'binaries':binary_cut,
           'crashImage':{p.name:sha(p) for p in image.iterdir()},'journal':summary,
           'modelExplorationPending':True,'productionExactlyOnceQualified':False}
  (folder/'crash-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
  print(json.dumps({'receipt':str(folder/'crash-receipt.json'),'workspace':str(root),
                    'phase':phase,'terminals':terminals,'resultStatus':result_status}))
 finally:
  sel.close()
  if process.poll() is None:
   os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=10)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--artifacts',type=Path,required=True)
 parser.add_argument('--phase',choices=['before-commit','after-commit'],default='before-commit')
 args=parser.parse_args();run(args.artifacts.resolve(),args.phase)
