"""Content binding for the migrated POO application artifact, not an evaluator."""
import hashlib
from importlib.util import find_spec
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import runtime_identity

def compiled_inputs():
    return runtime_identity()

def qualification_inputs(files):
    receipt=runtime_identity()
    from ascent.build import runtime_identity as core_identity
    core=core_identity()
    for name,sha in receipt['producerInputs'].items():
        key='rust/ascent/'+name+'/source.bin'
        if core['sourceInputs'].get(key)!=sha:
            raise ValueError('installed ASCENT producer differs from POO dependency: '+key)
    paths=[Path(find_spec(n).origin).resolve() for n in ('ascent._core','agentic_ai_lab_runtime._reasoning')]
    paths.extend(map(Path,files))
    return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
