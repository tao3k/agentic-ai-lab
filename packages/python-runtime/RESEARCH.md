# Application reasoning qualification

Application Evidence, Clue, Trajectory and model interaction are exposed through
`agentic_ai_lab_runtime.reasoning`. ASCENT supplies the generic rule evaluator and
provenance. See [ownership and validation](../../modules/evidence-assessment/migration.org).

Build the native extension from this Python project with the existing maturin
configuration, or through its setuptools Rust extension registration. Install the
ASCENT producer from the exact revision pinned in the native Cargo manifest.
The native receipt exposes `runtime_identity()`; study admission compares every
producer source hash with the independently installed ASCENT wheel and binds both
extension files. Mismatches fail admission.

The offline installed-consumer gate is:

```sh
PYTHONPATH=packages/python-testing/src python -m unittest discover -s packages/python-runtime/tests/scenarios
```

The existing study code lives in `agentic_ai_lab_testing.assessment_studies`.
Historical reports and failed/truncated runs retain their source identities in
`docs/research/agent-inference`. Their plans do not qualify the migrated package.
No provider call is part of the migration qualification gates.
