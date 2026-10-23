# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Freeze input bytes and independently preflight native computation."""
import json
import os
from pathlib import Path
import subprocess
import sys
from .tasks import DIRECT_FAMILIES, DIRECT_MODULES, digest, task_program, expected_value, sexp
from .native import native_run
from .worker import NativeStudyWorker, worker_source

def producer_hashes():
    files = [*Path(__file__).parent.glob('*.py'), Path(__file__).parent.parent/'direct_understanding.py',
             Path(__file__).parent.parent/'prediction_transport.py']
    return {str(path.relative_to(Path(__file__).parent.parent)): digest(path.read_bytes())
            for path in sorted(files)}

def dependency_modules(root, output):
    text = native_run(root, ['just', 'model-understanding-compute',
        str(root/'t/model-study/direct-understanding/source-closure.ss')],
        output/'source-closure.native.log')
    modules = json.loads(next(line for line in text.splitlines() if line.startswith('[')))
    project = [name for name in modules if name.startswith('gerbil-ascent/') or name == 'yuanxu/types']
    if not all('gerbil-ascent/'+name.removesuffix('.ss') in project for name in DIRECT_MODULES):
        raise ValueError('compiler source closure omits task entry modules')
    return project, [name for name in modules if name not in project]


def source_paths(root, ascent, modules):
    return {name: (ascent/(name.split('/', 1)[1]+'.ss')
                   if name.startswith('gerbil-ascent/') else root/(name+'.ss'))
            for name in modules}


def native_bindings(modules):
    prefix = Path(os.environ['GERBIL_PATH'])/'lib'
    files = []
    for module in modules:
        path = prefix/module
        compiled = list(path.parent.glob(path.name+'*.o1'))
        if not compiled:
            raise ValueError(f'qualified compiled module missing: {module}')
        files.extend(compiled)
    return {str(path): digest(path.read_bytes()) for path in sorted(set(files))}


def prepare(root, ascent, output):
    output.mkdir(parents=True, exist_ok=False)
    modules, frameworks = dependency_modules(root, output)
    sources = source_paths(root, ascent, modules)
    context = '\n'.join(f';;; file: {module}.ss\n'+path.read_text()
                        for module, path in sources.items())
    manifest = {'schema': 'agentic-ai-lab.direct-scheme-understanding-plan', 'version': 1,
        'model': 'deepseek-flash', 'maxCalls': 30, 'retries': 0,
        'maxInputBytes': 393216, 'maxOutputTokens': 8192, 'budgetCeilingUsd': 4,
        'conservativeMaximumUsd': 30*(393216*.3+8192*1.2)/1_000_000,
        'pooHead': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'ascentHead': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ascent, text=True).strip(),
        'dependencyModules': modules, 'frameworkModules': frameworks,
        'modules': {name: digest(path.read_bytes()) for name, path in sources.items()},
        'templates': {name: digest((root/'t/model-study/direct-understanding'/f'{name}.ss').read_bytes())
                      for name in DIRECT_FAMILIES},
        'producerHashes': producer_hashes(),
        'nativeBindings': native_bindings(modules),
        'scorerSha256': digest((root/'t/model-study/direct-understanding/prediction-score.ss').read_bytes()),
        'predictionCoreSha256': digest((root/'t/model-study/direct-understanding/prediction-core.ss').read_bytes()),
        'workerLoopSha256': digest((root/'t/model-study/direct-understanding/worker-loop.ss').read_bytes()),
        'workerScriptSha256': digest(worker_source(root).encode()),
        'computeLoaderSha256': digest((root/'t/model-study/direct-understanding/compute-loader.ss').read_bytes()),
        'closureProbeSha256': digest((root/'t/model-study/direct-understanding/source-closure.ss').read_bytes()),
        'inputContract': 'actual module source and Scheme check-equal? task with missing expected datum; no semantic instructions',
        'sourceClosure': 'compiler-derived ASCENT runtime project closure plus yuanxu/types; language and POO framework modules explicitly listed as assumed dependencies, not supplied source',
        'outputContract': 'bounded explicit literal or quoted check-equal? prediction; differing explicit data reject; bare fences fallback only; never evaluated',
        'transportContract': 'raw preserved; unique inert data normalized without oracle; EOF, placeholder and ambiguity reject',
        'cases': [], 'order': []}
    imports = ''
    for module in (':gerbil-ascent/program/scheme-language',):
        imports += f'(displayln "IMPORT {module}") (force-output)\n(import {module})\n(displayln "MODULE-OK {module}") (force-output)\n'
    worker_script = output/'native-worker.ss'
    worker_script.write_text(worker_source(root))
    worker = NativeStudyWorker(root, worker_script, output/'native-worker.log')
    try:
        for family in DIRECT_FAMILIES:
            for variant in ('initial', 'transfer'):
                case = f'{family}-{variant}'
                program = task_program(root, family, variant)
                task = output / f'{case}.ss'
                task.write_text(imports + program + '\n(write result) (newline)\n(displayln "HARNESS-OK direct-compute")\n(displayln "OK") (force-output)\n')
                log = output / f'{case}.native.log'
                result = worker.compute(case)
                log.write_text(json.dumps(result, sort_keys=True)+'\n')
                actual = result['nativeDatum'].rstrip('\n')
                expected = sexp(expected_value(family, variant))
                if actual != expected:
                    raise AssertionError(f'independent oracle mismatch {case}: {actual} != {expected}')
                private = output / 'private'; private.mkdir(exist_ok=True)
                (private / f'{case}.sexp').write_text(actual+'\n')
                payload = context + '\n(import :std/test :gerbil-ascent/program/scheme-language)\n' + program + "\n(check-equal? result '?)\n"
                if len(payload.encode()) > manifest['maxInputBytes']:
                    raise ValueError('source/task input exceeds frozen byte bound')
                (output / f'{case}.input.ss').write_text(payload)
                manifest['cases'].append({'id': case, 'family': family, 'variant': variant,
                    'inputSha256': digest(payload.encode()), 'inputBytes': len(payload.encode()),
                    'nativeProgramSha256': digest(task.read_bytes()), 'expectedSha256': digest((actual+'\n').encode())})
                sys.stdout.write(f'COMPUTE-OK {case}\n'); sys.stdout.flush()
    finally:
        worker.close()
    for index, family in enumerate(DIRECT_FAMILIES):
        initial_arms = [('initial-none', 'none', 'initial'), ('initial-high', 'high', 'initial')]
        transfer_arms = [('transfer-fresh', 'high', 'transfer'),
                         ('transfer-history', 'high', 'transfer'),
                         ('transfer-feedback', 'high', 'transfer')]
        rotation = index % 3
        transfer_arms = transfer_arms[rotation:]+transfer_arms[:rotation]
        if index % 2:
            initial_arms.reverse(); transfer_arms.reverse()
        for arm, effort, variant in initial_arms + transfer_arms:
            manifest['order'].append({'family': family, 'arm': arm, 'reasoningEffort': effort,
                                      'case': f'{family}-{variant}'})
    encoded = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
    (output/'plan.json').write_bytes(encoded)
    sys.stdout.write(f'PREPARED {digest(encoded)} native=12 modelCalls=0\n'); sys.stdout.flush()
    return manifest
