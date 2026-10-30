# Fixed-Window Evidence Reads

Evidence growth must not make a previously usable query fail merely because
all per-family summaries no longer fit together. Inference still evaluates the
caller's complete Scheme selector. Presentation can replace pending summaries
with `deferredScope`: a source identity, content identity and claim count.
The scope's support/counter counts remain in the brief.

Only complete displayed families enter the checkpoint. Repeating the selector
with that checkpoint exposes unseen families; changing the selector or expanding
another claim remains allowed. A group reference is not a recommendation,
execution permission, or acknowledgement of its hidden bodies. Explicit scope
claims remain inline whenever their header fits; an oversized header uses the
same content-bound representation. Wide derived question rows use the existing
relation-reference mechanism.

The minimum identity/reference envelope must still fit. A single oversized
family or derived relation can remain deferred; this change does not fabricate
completion or split a witness from its counterevidence.

## Validation

- `wide_scope_pages_without_acknowledging_grouped_references` reads 96 families
  through the unchanged 8192-byte window. Every family retains both witnesses,
  every family is displayed exactly once, and the complete set is recovered.
- The full Rust integration inventory passes 86 tests, including the actual
  Scheme/Rust oracles, after restoring the declared Gerbil dependencies and
  selecting the current source with `GERBIL_LOADPATH`.
- The SMP consumer's progressive/exploration inventory passes 44 tests on the
  source-built wheel. Its published dependency remains a separate qualification.
- `ProgressiveEvidenceRead` passes its positive check and all six existing
  negative controls. Grouped references cannot acknowledge hidden evidence.
- `AnchoredEvidenceSlice.lean` proves the cardinality-independent pending
  partition and non-acknowledgement laws through the locked LeanPoo Guard.
- Strict library Clippy passes without suppressions.

Reproduce from the repository root, using the declared toolchain environment:

```sh
GERBIL_PATH="$PWD/.gerbil" gxpkg deps --install
GERBIL_LOADPATH="$PWD" cargo test --locked --manifest-path rust/Cargo.toml -p gerbil-ascent --test integration_test
just _check-quint ProgressiveEvidenceRead
just check-lean-file AnchoredEvidenceSlice.lean
cargo clippy --locked --manifest-path rust/Cargo.toml -p gerbil-ascent --lib -- -D warnings
```

Build Python artifacts through the `python/` project entrypoint, not the internal
Cargo-only project. Model and consumer passes do not establish an SMP runtime
repair, reduced agent repetition, or a native performance improvement.
