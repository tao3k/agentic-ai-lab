#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify real background timers, owner delivery, current-clock fences and replay."""
import argparse
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('authority_gate',HERE/'run-native-authority.py')
authority=importlib.util.module_from_spec(spec)
spec.loader.exec_module(authority)
base=authority.base
ROOT=authority.ROOT
INPUTS=tuple(dict.fromkeys((*authority.INPUTS,'build-spec.ss',
 'modules/temporal-causality/runtime/monotonic-clock.ss',
 'modules/temporal-causality/runtime/policy-clock.ss',str(Path(__file__).resolve().relative_to(ROOT)))))
ALL=[p for p in itertools.permutations(range(1,6)) if p.index(4)<p.index(5)]


def binaries():
    result=authority.dependency_artifacts()
    folder=ROOT/'.gerbil/lib/agentic-ai-lab/modules/temporal-causality/runtime'
    for prefix in ('monotonic-clock','policy-clock'):
        for p in folder.glob(prefix+'*'):
            if p.is_file() and (re.search(r'\.o[0-9]+$',p.name) or p.suffix=='.ssi' or p.name.endswith('.ssxi.ss')):
                result[str(p.relative_to(ROOT))]=base.sha(p)
    return result


def inspect(log,exitcode,orders):
    regression=authority.inspect(log,exitcode,authority.push.DEFAULT)
    text=re.sub(r'\n@yuanxu-progress \[\"[^\"\n]+\",[0-9]+\]\n','',log.read_text())
    rows=text.splitlines()
    observations=[r for r in rows if r.startswith('NATIVE-CLOCK-OBSERVE ')]
    if observations!=[
      'NATIVE-CLOCK-OBSERVE autonomous no-context-query-before-push=#t applied=1 duplicate=1 unaffected=completed originals-retained=#t',
      'NATIVE-CLOCK-OBSERVE completion-before-deadline published=#t historical-terminal=completed current-after-expiry=#f duplicate-terminal=#f',
      'NATIVE-CLOCK-OBSERVE delayed guard-expires-before-result=#t queued-old-stale=#t duplicate-idempotent=#t',
      f'NATIVE-CLOCK-OBSERVE races paths={len(orders)} duplicate-terminals=0 old-ticket-new-policy-damage=0 stale-reactivations=0 unaffected-failures=0']:
        raise RuntimeError('Missing actual autonomous/delayed/race verdicts')
    controls=[r for r in rows if r.startswith('NATIVE-CLOCK-COUNTEREXAMPLE ')]
    if controls!=['NATIVE-CLOCK-COUNTEREXAMPLE no-timer cached-admitted=#t active-after-deadline=#t final-clock-guard-denies=#t']:
        raise RuntimeError('Missing real disabled-timer counterexample')
    begins=[];paths=[];events=[];evidence=[]
    for line in rows:
        if line.startswith('NATIVE-CLOCK-BEGIN '):
            m=re.fullmatch(r'NATIVE-CLOCK-BEGIN order=\(([1-5 ]+)\)',line)
            if not m:raise RuntimeError('Malformed clock begin')
            begins.append(tuple(map(int,m[1].split())))
        elif line.startswith('NATIVE-CLOCK-PATH '):
            m=re.fullmatch(r'NATIVE-CLOCK-PATH order=\(([1-5 ]+)\) received=2 applied=([01]) stale=([01]) duplicate=1 old-current=#f new-current=#t unaffected=#t',line)
            if not m:raise RuntimeError('Malformed actual native clock result')
            order=tuple(map(int,m[1].split()));applied=int(m[2]);stale=int(m[3])
            expected=int(order.index(1)<min(order.index(2),order.index(3)))
            if applied!=expected or stale!=1-expected:raise RuntimeError('Wrong ticket lifecycle verdict')
            paths.append({'order':list(order),'applied':applied,'stale':stale,'duplicate':1,'new_current':True,'old_current':False})
        elif line.startswith('NATIVE-CLOCK-EVENT '):
            m=re.fullmatch(r'NATIVE-CLOCK-EVENT case=(autonomous|completed-before|delayed-guard|race) phase=(received|applied|stale|duplicate) cause=(timer|operation) ticket=(sha256:[0-9a-f]{64}) policy=policy generation=1 policy-digest=(sha256:[0-9a-f]{64}) end=4 observed=([0-9]+) deadline=([0-9.]+) sample=([0-9.]+)',line)
            if not m or int(m[6])<4 or float(m[8])<float(m[7]):raise RuntimeError('Missing native monotonic ticket evidence')
            events.append(dict(zip(('case','phase','cause','ticket','policy_digest','observed','deadline','sample'),m.groups())))
        elif line.startswith('NATIVE-CLOCK-EVIDENCE '):
            m=re.fullmatch(r'NATIVE-CLOCK-EVIDENCE journal=(sha256:[0-9a-f]{64}) proof=(sha256:[0-9a-f]{64}) event=(sha256:[0-9a-f]{64}) context-index=(sha256:[0-9a-f]{64})',line)
            if not m:raise RuntimeError('Missing original proof/journal and propagated index')
            evidence.append(dict(zip(('journal','proof','event','context_index'),m.groups())))
    if begins!=orders or [tuple(p['order']) for p in paths]!=orders or len(evidence)!=len(orders)+2:
        raise RuntimeError('Clock corpus incomplete, duplicated or reordered')
    if len(events)!=4*(len(orders)+3):raise RuntimeError('Missing duplicate/native delivery audit')
    if any(e['cause']!='timer' for e in events if e['case']=='autonomous'):
        raise RuntimeError('Autonomous expiry was query-triggered')
    return {'regression':regression,'observations':observations,'counterexamples':controls,'paths':paths,'events':events,'evidence':evidence}


def verify(path):
    r=json.loads(path.read_text())
    if (r['schema']!='context.native-background-clock.v1' or set(r['source_sha256'])!=set(INPUTS)
      or any(base.sha(ROOT/p)!=h for p,h in r['source_sha256'].items())
      or r['ascent_head']!=base.ascent_revision(ROOT) or r['orgize_head']!=base.orgize_revision(ROOT)
      or r['binaries']!=binaries()):raise RuntimeError('Native clock source/dependency/binary cut is stale')
    for name,digest in r['artifacts'].items():
        if base.sha(path.parent/name)!=digest:raise RuntimeError('Clock artifact commitment mismatch')
    orders=[tuple(p) for p in r['orders']]
    if (not all(p in ALL for p in orders) or len(set(orders))!=len(orders)
      or (r['mode']=='all' and orders!=ALL) or (r['mode']=='replay' and len(orders)!=1)):
        raise RuntimeError('Invalid saved clock corpus')
    actual=inspect(path.parent/'native.log',r['native_exit'],orders)
    if actual!=r['execution'] or json.loads((path.parent/'paths.json').read_text())!=actual['paths']:
        raise RuntimeError('Saved clock verdicts disagree with actual native evidence')
    return r


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts',type=Path)
    parser.add_argument('--order')
    parser.add_argument('--reuse-build',type=Path)
    parser.add_argument('--check-receipt',type=Path)
    args=parser.parse_args()
    if args.check_receipt:
        r=verify(args.check_receipt)
        print(f'CURRENT CLOCK RECEIPT: {len(r["orders"])} actual owner paths; {args.check_receipt}')
        return
    orders=ALL
    if args.order:
        orders=[tuple(map(int,args.order.split(',')))]
        if orders[0] not in ALL:raise RuntimeError('Illegal native clock path')
    artifacts=args.artifacts or Path(tempfile.mkdtemp(prefix='context-clock-',dir='/private/tmp'))
    artifacts.mkdir(parents=True,exist_ok=True)
    before={p:base.sha(ROOT/p) for p in INPUTS}
    ascent,orgize=base.ascent_revision(ROOT),base.orgize_revision(ROOT)
    env=os.environ.copy()
    for name in tuple(env):
        if name.startswith('AGENTIC_CONTEXT_'):env.pop(name)
    env.update(GERBIL_PATH=str(ROOT/'.gerbil'),GERBIL_LOADPATH=f'{ROOT}:{ROOT}/.gerbil/lib:{ROOT}/dev/.gerbil/lib')
    if args.order:env['AGENTIC_CONTEXT_CLOCK_ORDER']='('+' '.join(map(str,orders[0]))+')'
    if args.reuse_build:
        verify(args.reuse_build)
        shutil.copyfile(args.reuse_build.parent/'build.log',artifacts/'build.log')
    else:
        with (artifacts/'build.log').open('w') as output:
            subprocess.run(['just','build-library'],cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=600,check=True)
    binary_cut=binaries()
    with (artifacts/'native.log').open('w') as output:
        result=subprocess.run(['just','test-context-clock'],cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=915)
    if (base.ascent_revision(ROOT)!=ascent or base.orgize_revision(ROOT)!=orgize
      or any(base.sha(ROOT/p)!=h for p,h in before.items()) or binaries()!=binary_cut):
        raise RuntimeError('Runtime cut changed during clock execution; partial logs retained')
    actual=inspect(artifacts/'native.log',result.returncode,orders)
    (artifacts/'paths.json').write_text(json.dumps(actual['paths'],indent=2)+'\n')
    r={'schema':'context.native-background-clock.v1','mode':'replay' if args.order else 'all',
       'orders':orders,'native_exit':result.returncode,'source_sha256':before,'ascent_head':ascent,'orgize_head':orgize,
       'binaries':binary_cut,'execution':actual,'artifacts':{p:base.sha(artifacts/p) for p in ('build.log','native.log','paths.json')},
       'scope':{'os_monotonic_timer':True,'owner_reactor':True,'no_query_push':True,'delayed_duplicate_queue_orders':True,
                'all_machine_interleavings':False,'persistent_crash_recovery':False,'provider_kv_cache_benchmark':False}}
    path=artifacts/'clock-receipt.json';path.write_text(json.dumps(r,indent=2)+'\n')
    print(f'PASS: {actual["regression"]["regression"]["case_count"]} native Cases, {len(orders)} real clock paths; {path}')


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.SubprocessError) as e:
        print(f'ERROR: {e}',file=sys.stderr);sys.exit(1)
