#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute crash-boundary contracts, unsafe witnesses and exact safe replay."""
import argparse, hashlib, itertools, json, subprocess, tempfile
from pathlib import Path

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',type=Path);p.add_argument('--replay',type=Path);a=p.parse_args()
 model=Path(__file__).with_name('14-durable-recovery.sysml')
 out=a.artifacts or Path(tempfile.mkdtemp(prefix='context-durable-sysml-',dir='/private/tmp'));out.mkdir(parents=True,exist_ok=True)
 jobs=list(itertools.product(range(3),(False,True),range(8)))
 if a.replay:
  r=json.loads(a.replay.read_text())
  if r['model_sha256']!=sha(model):raise RuntimeError('Stale durable model')
  c,b,m=r['inputs'];jobs=[(c,b,m),(c,b,0)]
 subjects=[f'ContextDurableRecovery::Crash({c},{str(b).lower()},{m})' for c,b,m in jobs]
 command=['sysml','-strict','-no-record-cache',str(model),'-engine','run','-json']
 for s in subjects:command+=['-analysis',s]
 r=subprocess.run(command,capture_output=True,text=True,timeout=45)
 (out/'sysml.json').write_text(r.stdout);(out/'stderr.txt').write_text(r.stderr);d=json.loads(r.stdout)
 checks=d.get('checks') or []
 if d.get('errors') or d.get('diagnostics') or len(checks)!=len(jobs):raise RuntimeError('Incomplete durable SysML run')
 failed=0
 for inputs,s,c in zip(jobs,subjects,checks):
  window,replaced,mode=inputs
  bad=mode in (1,4,5,7) or (mode==2 and window!=2) or (mode==3 and replaced) or (mode==6 and window!=2)
  vals={v['name']:v['value'] for v in c.get('values') or []};e=c.get('results') or [];v=c.get('verifications') or []
  if c.get('subject')!=s or c.get('status')!=('fails' if bad else 'holds') or vals.get('processed')!='3' or vals.get('retained')!='true' or len(v)!=1 or v[0].get('kind')!=('fail' if bad else 'pass') or len(e)!=1 or e[0].get('engine')!='run' or e[0].get('claim')!=('violated' if bad else 'holds') or any(b.get('reached') for z in e for b in z.get('bounds',[])):raise RuntimeError(f'Wrong executed durable verdict: {inputs}')
  if bad:
   failed+=1;(out/f'counterexample-{window}-{replaced}-{mode}.json').write_text(json.dumps({'inputs':inputs,'model_sha256':sha(model),'actual':c},indent=2)+'\n')
 if r.returncode!=(1 if failed else 0):raise RuntimeError('Wrong CLI exit')
 (out/'summary.json').write_text(json.dumps({'executed':len(jobs),'expected_unsafe_failures':failed,'safe_failures':0,'model_sha256':sha(model),'native_storage_proof':False},indent=2)+'\n')
 print(f'PASS: {len(jobs)} executed, {failed} expected unsafe; {out}')
if __name__=='__main__':main()
