# Evidence DSL Library

## Library Boundary

ASCENT is a Library for Agentic AI. A downstream Python application defines
its scenario DSL; it does not own a Gerbil package or Scheme compile step.
Catalog, review, history and investigation policies belong to the consumer,
not fixed features of this Library. Fragment is a composition unit, not the
only intended consumer entry.

Downstream source contains ordinary definitions and native ASCENT expressions.
It contains no Scheme `import`, `module` or `export`; those top-level forms are
rejected by this entry. The Library internally supplies its Evidence interface,
upstream operators, aggregators and lattice constructors in a fresh hygienic
native scope. No downstream `gerbil.pkg`, `build.ss` or compiler is needed.

```python
from ascent_engine import Engine

dsl = """
(define-evidence (make-scene rows)
  (sources facts)
  (outputs answers)
  (relation facts (value) rows)
  (relation answers (value))
  ((answers value) <-- (facts value)))
"""
with Engine() as engine:
    with engine.evidence(dsl, 'make-scene', [[1], [2]], trusted=True) as session:
        receipt = session.run()
        with session.result(receipt) as result:
            graph = result.rows('answers')
```

`Engine.dsl(source, trusted=True)` supports arbitrary user constructors,
hygienic macros, closures and reusable inference components through native
calls. `Engine.evidence` opens the declared Evidence session. Fragment
remains available for composition, not the sole entry. Native handles, including
gensyms, retain their identity; Python does not reconstruct printed names.

Explicit `trusted=True` is required by Python and native entry validation.
Definitions run as trusted host Scheme code and may have effects; this is not
a sandbox or permission grant. The host must authorize code and bind source
identities. Library maintenance builds remain owned by `build.ss`,
`defbuild-script` and upstream `std/make`; runtime DSL expansion does not invoke
a downstream compiler.

Source is bounded to 262144 UTF-8 bytes and 256 top-level definitions. Source
scope admission defaults to unlimited; `Engine(max_source_scopes=N)` supplies
an optional process-lifetime ceiling, including failed expansions after reader
admission. Closing a scope releases ABI-owned values; it does not unload
expander contexts or reset the admission count. Retain and reuse a scope, and
explicitly manage any user-defined external resource protocol.

## Declarative Evidence

`define-evidence` accepts upstream relation declarations and rules directly.
`sources` names the relations that the caller may replace; `outputs` declares
public result bindings. Both are explicit, even for a source-free program.
The Library's hygienic macro lowers this declaration through upstream `ascent`;
Python neither parses these clauses nor evaluates rules.

```scheme
(define-evidence (make-review)
  (sources claim dependency)
  (outputs (requirements reachable) missing)
  (relation claim (subject))
  (relation dependency (subject premise))
  (relation reachable (subject premise))
  (relation missing (subject premise))
  ((reachable subject premise) <-- (dependency subject premise))
  ((reachable subject premise) <--
    (dependency subject intermediate) (reachable intermediate premise))
  ((missing subject premise) <--
    (claim subject) (reachable subject premise) (not (claim premise))))
```

The result alias `requirements` binds the declared relation `reachable`.
An identifier binding names a relation, not a Scheme variable; an operator's
computed handle can instead use `(public-name (relational-export op 'name))`.
Constructors may take parameters, and reusable hygienic macros can emit rules.
Aggregators, lattices, negation, operators and explicit upstream `bounds`
retain their upstream contracts. Fragment is useful for reusable rule groups,
not required around every relation declaration or single-use rule.

An optional `(explain callback)` follows the binding clauses. The default
records native rule dependencies and current source rows, with an explicit
per-row-proof gap. Source and output bindings are validated against the native
Program; a result alias cannot authorize source replacement. Public bindings
do not filter the Program's execution or make unprojectable values disappear.
The older Program-returning `define-evidence` form remains available for
constructors that need general Scheme composition, not as the primary example.

## General Native Module Calls

`Engine.module` also exposes Library-bundled modules. It does not require a Program
return value or an inert Fragment document. `Module.call` invokes an
actual exported Scheme procedure; `Value.reference` transports its
owned native object to subsequent calls. An optional `module=` selects another
compiled module in the same ownership scope. Ordinary Scheme modules own
constructors, hygienic macros, builders and contracts; Python neither expands
syntax nor reconstructs relational objects.

```python
with engine.module(':gerbil-ascent/program/interface') as module:
    with module.call('relational-op-source',
                     {'type': 'symbol', 'value': 'edge'}, 2, [[0, 1]]) as source:
        with module.call('relational-op-project', source.reference(), [1]) as op:
            # op is an actual upstream operator, not JSON describing an operator.
            with module.call('relational-op-fragment', op.reference(),
                             {'type': 'symbol', 'value': 'targets'}) as fragment:
                with module.call('relational-compose', [fragment.reference()],
                                 16, 64, 128) as program:
                    with module.call('relational-open-session', program.reference()) as session:
                        with module.call('relational-session-run', session.reference()) as result:
                            with module.call('relational-query', result.reference(),
                                             fragment.reference(),
                                             {'type': 'symbol', 'value': 'targets'}) as rows:
                                graph = rows.graph
```

Upstream prepared queries return actual native procedures; `Value.apply`
calls those procedures in Scheme. Prepared change plans and retained operator
sessions remain upstream objects too. Multiple Scheme return values retain
their order in a native vector, with explicit `valueCount` metadata. A single
return remains the actual value, even when that value itself is a vector.
Graph projection failure preserves the owned value and a reference-only result;
it does not rerun, simplify or replace execution. Source/fact limits are those
of the chosen upstream Program or operation, not a hidden Python language tier.

Each module owner retains at most 64 return values. Release values or close the
owner when finished; foreign-owner and released references fail. Native objects
may be mutable, and native procedure calls may have effects. Generic calls do
not promise automatic rollback, immutable snapshots, derivation certificates or
authorization. Use the selected upstream object's transaction and shutdown
contracts. Closing the ABI owner releases its references, not arbitrary
user-defined resource protocols. Bounds and trusted-code authority still apply.

`open_module` remains a convenience for the Program/session/result/explanation
protocol. `open_sources` is a deliberately pure DSL text entry and `read_rules`
is the finite wire projection. Neither is the boundary of the Scheme language
available through general compiled-module calls.

## Results And Explanations

`SourceSession.run` retains the actual upstream result and returns a
`resultHandle`. `session.result(receipt)` owns that handle. Its `rows(name)`
method returns a `native-value-graph.v1` transport: exact numbers, symbols,
characters, pairs, vectors, byte vectors and hash tables have explicit tags;
shared and cyclic objects use references. Opaque values remain retained native
objects. The legacy scalar projection is explicitly partial when it cannot
represent a cell; it never selects or reduces executable semantics.

An optional native explanation procedure takes `(program result query scope)`.
`scope` supplies the current source generation and accepted source rows, with
the shared nested-value immutability premise. The callback may retain native
dependencies, provenance and explicit gaps. Its explanation is a separate
owned handle. Without a callback the engine reports a missing derivation proof
alongside native declaration dependencies and the current scope. Declaration
dependencies alone are not row certificates, causal reviews or authorization.

Typed constructor/update arguments encode symbols, exact numbers, characters,
vectors, byte vectors and pairs. A `reference` argument can reuse a native node
from a result owned by the same session and generation. Python transports these
tags; Scheme resolves the values and upstream ASCENT validates/evaluates them.

Release result and explanation handles when finished. Successful source
replacement invalidates previous generation handles; rejected updates do not.
Closing the source session retires all its results. Result and explanation
handles are distinct, and foreign-session or stale references are rejected.
Transport/session bounds are explicit lifecycle limits, not language semantics.
Neither scalar projection nor explanation availability gates native execution.
`with result.explanation(name) as explanation:` provides independent Python
ownership for the native explanation handle; `explanation.graph` preserves its
dependencies, source scope and gaps. The raw `explain` method remains available
when the host explicitly manages the returned handle.

## Qualification Boundary

A completed, source-matched build, fresh-process loading, actual upstream
queries, updates, negative controls and teardown are separate checks. Timeout
protection and historical binaries are not evidence that loading was repaired.
The current native module regression controls are in
`python/engine_tests/test_modules.py`; run them against the newly built
artifact, not a previous receipt.
`python/engine_tests/test_module_calls.py` additionally exercises general
calls, cross-module lattice objects, checked-session rejection, native POO
readers, retained updates/withdrawal, prepared changes, closures, multiple
values, ownership bounds and repeated explanation cleanup.

Public interface qualification is distinct from any downstream Agentic AI application migrating
its catalogs and history to this entry. A provider supporting general calls does
not establish that an existing Fragment-based consumer uses them.
# Real Agentic AI Scenario

The downstream investigation scenario exercises complete failure inventory,
receipt fields and declared dependencies through import-free DSL definitions,
native aggregation, lattice, operators, withdrawal and separate explanations.
Its scenario policy is a consumer asset, not a fixed Library feature. Local
scenario success does not establish whole-consumer capacity or admission.

