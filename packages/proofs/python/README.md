<!--
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
-->

# agentic-ai-lab-proof

Typed Lean artifact generator for agentic-ai-lab proof manifests.

This package emits Lean declarations that use constructors from
`AgenticAILabProof.Manifest`.

```sh
uv run agentic-ai-lab-proof emit-lean --output ../lean/AgenticAILabProof/Generated/LoopEngine.lean
```

## Native proof runtime

`NativeProofCaseRuntime` is the production-capable Python adapter for the
stable `agentic_ai_lab_proof_case_v1` C ABI. It consumes the generated native Scheme
type projection directly; JSON is not part of this boundary.

```python
from agentic_ai_lab_proof.proof_case_runtime import (
    NativeProofCaseRuntime,
    assert_native_differential,
)

runtime = NativeProofCaseRuntime("/path/to/libagentic_ai_lab_runtime.dylib")
layout = assert_native_differential(runtime, native_vector)
```

For the production caller-owned path, reuse an output buffer. ABI layout and
fingerprint negotiation happens once per runtime instance; thread-local CFFI
scratch objects are reused after their first call:

```python
output = bytearray(424)
layout = runtime.validate_and_write(native_vector, output)
```

The differential gate requires Python and C to agree on validation status,
schema fingerprint, ABI layout, and the exact round-trip bytes. Rust,
TypeScript, and other language runtimes remain downstream adapters over the
same C ABI.

The installed-consumer gate builds a non-editable wheel, installs it into an
isolated virtual environment, removes `PYTHONPATH`, and verifies the canonical
vector through the public shared library:

```sh
uv run pytest -q tests/test_installed_wheel.py
```
