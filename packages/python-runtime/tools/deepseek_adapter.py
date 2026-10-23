# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""DeepSeek HTTP adapter for one ASP-owned frozen Scheme task; no benchmark authority."""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'packages/python-testing/src'))
from agentic_ai_lab_testing.model_study.semantic_config import configuration
from agentic_ai_lab_runtime import scheme_wire as wire
from agentic_ai_lab_testing.model_study.semantic_provider import predict

def report_progress(*parts: object, end: str = '\n') -> None:
    """Emit this CLI's bounded progress on its owned stdout channel."""
    sys.stdout.write(' '.join(str(part) for part in parts) + end)
    sys.stdout.flush()

sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path, required=True)
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--oracle', type=Path, required=True)
parser.add_argument('--env-file', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--case', required=True)
a = parser.parse_args()
config = configuration(a.env_file)
cases = [v for v in wire.loads(a.oracle.read_bytes()) if v['name'] == a.case]
if len(cases) != 1:
    raise ValueError('exactly one frozen Scheme oracle case required')
model = config.get('DEEPSEEK_MODEL', config.get('ANTHROPIC_MODEL', 'deepseek-v4-pro'))
artifact_digest = sha(a.library)
with a.output.open("x") as claim:
    claim.write(wire.dumps({"schema":"agentic-ai-lab.provider-family-case.v1", "case":a.case, "passed":False, "state":"claimed", "maximumCalls":2, "retries":0}) + "\n")

async def run():
    records=[]
    for i,case in enumerate(cases):
        report_progress('REAL-MODEL RUST FAMILY',case['name'])
        r=dict(case=case['name'],passed=False,tool={},final={})
        task=case['payload']
        request=dict(model=model,reasoning={'effort':'none'},temperature=0.0,max_output_tokens=4096,stream=True,
            input=[dict(role='user',content='Invoke the read-only tool once. Copy this exact Scheme datum into the datum string parameter:\n'+wire.dumps(task))],
            tools=[dict(type='function',name='agentic_ai_lab_temporal_family_classify',description='Read-only finite hypothesis family classification.',
                        parameters=dict(type='object',properties={'datum':dict(type='string')},required=['datum'],additionalProperties=False))],
            tool_choice=dict(type='function',name='agentic_ai_lab_temporal_family_classify'))
        try:
            await predict(request,config['DEEPSEEK_API_KEY'],r['tool'],emit=lambda _:report_progress('.',end=''),content_event='response.function_call_arguments.delta')
            calls=r['tool'].get('toolCalls',[])
            if len(calls)!=1 or calls[0].get('name')!='agentic_ai_lab_temporal_family_classify':raise ValueError('wrong tool call')
            call=calls[0]
            # Duplicate keys rejected before equality checking.
            def unique(pairs):
                d={}
                for k,v in pairs:
                    if k in d:raise ValueError('duplicate JSON key')
                    d[k]=v
                return d
            arguments=json.loads(call['arguments'],object_pairs_hook=unique)
            if set(arguments) != {'datum'} or not isinstance(arguments['datum'], str):raise ValueError('wrong provider envelope')
            bound_task = wire.loads(arguments['datum'])
            if wire.dumps(bound_task)!=wire.dumps(task):raise ValueError('tool changed bound task')
            env=dict(os.environ,AGENTIC_AI_LAB_SEMANTIC_LIBRARY=str(a.library),AGENTIC_AI_LAB_SEMANTIC_SHA256=artifact_digest)
            start=time.monotonic()
            child=await asyncio.create_subprocess_exec(str(a.binary),stdin=asyncio.subprocess.PIPE,stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE,env=env)
            try:
                stdout,stderr=await asyncio.wait_for(child.communicate(wire.dumps(dict(operation='temporal.family.classify',payload=task)).encode()),5)
            except BaseException:
                child.kill();await child.wait();raise
            if child.returncode:raise ValueError('Rust consumer failed: '+stderr.decode())
            result=wire.loads(stdout);r['nativeSeconds']=time.monotonic()-start;r['nativeResult']=result
            if result!=case['expected']:raise ValueError('Rust native result differs from frozen native oracle')
            fields=['classification','bindingDigest','modelDigest','exhausted','sourceAuthenticated','actionAuthorized']
            expected={k:result[k] for k in fields}
            final=dict(model=model,reasoning={'effort':'none'},temperature=0.0,max_output_tokens=2048,stream=True,
                input=request['input']+[call,dict(type='function_call_output',call_id=call['call_id'],output=wire.dumps(result)),
                                       dict(role='user',content='Return only these fields from the actual Library output as one Scheme datum: classification, bindingDigest, modelDigest, exhausted, sourceAuthenticated, actionAuthorized. Use (object ("field" value) ...), strings in quotes, booleans #t/#f. No markdown.')])
            raw=await predict(final,config['DEEPSEEK_API_KEY'],r['final'],emit=lambda _:report_progress('.',end=''))
            r['modelText']=raw
            if wire.loads(raw)!=expected:raise ValueError('final differs from actual native result')
            r['modelResult']=wire.loads(raw)
            r['boundTask']=bound_task
            r['passed']=True
        except Exception as e:r['failure']=type(e).__name__+': '+str(e)
        # Provider HTTP JSON is decoded here. Project files and subprocess IO are
        # Scheme values; no request/SSE transcript is stored as a JSON artifact.
        for phase in ('tool', 'final'):
            metrics = r[phase]
            r[phase] = {k:metrics[k] for k in ('responseId','responseStatus','seconds',
                'firstContentSeconds','contentGapsSeconds','usage','progressKind') if k in metrics}
        r.update(schema='agentic-ai-lab.provider-family-case.v1', model=model,
                 nativeArtifactSha256=artifact_digest, retries=0)
        a.output.write_text(wire.dumps(r) + '\n')
        report_progress(' RESULT',r['passed'],r.get('failure',''))
        return 0 if r['passed'] else 1
sys.exit(asyncio.run(run()))
