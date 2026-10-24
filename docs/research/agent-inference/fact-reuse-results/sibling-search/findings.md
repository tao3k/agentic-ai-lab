# Native evidence consumption: mechanism and limits

The clean checkout reproduction passes. Named native evidence and shared DAG
nodes now travel through actual paired model tool IO. The initial interaction
failure is repaired: both Scheme cells receive a subsequent model response
that consumes the returned evidence. This does **not** establish less repeated
thinking or better exploration under the same budget.

## What caused the observed failures

The earlier shared-premise model recognized supplied proof fragments and then
said “Let me verify path(0,2) via graph.” Evidence was ordinary user JSON beside
the complete graph, with no evidence-reading tool, and “transitions” caused
additional interpretation checks. This is an observable rechecking pattern,
not a complete causal account of model internals.

In the first sibling-search run, the model solved much of the optimization
before asking for evidence: “Let me now call read_paths to confirm, then
submit.” Both Scheme cells then stopped before any response could consume the
tool result. For source 0, 10,957 thinking tokens became 27,822 characters in
the replay; byte-based input reservation grew to 43,460 despite only 12,451
known tokens spent. That is a transport/budget censoring failure, not cache
savings. [The failed run](history/initial-transport/report.md) and all raw
thinking/annotation failures remain retained.

`ComputationalEvidence.observe` remains a wire projection of native Scheme
`fact` and `fragment`, with stale/unknown results preserved. It shares the
source scope once and publishes each support node once per packet; conclusion
roots refer to that native DAG. Python does not infer or admit proofs.
Continuation reservations use preceding measured input plus all output, then
add conservative UTF-8 bounds for genuinely new tool results. Every actual
provider usage is checked against reservation, output cap and total ceiling.
No anti-repetition prompt, forced evidence call, branch pruning or native
optimization answer is introduced.

## Frozen comparison

Two finite sources each have sixteen items, common derived path prerequisites,
pair bonuses and six sibling branches with different resource and membership
constraints. Each arm forks the same root and receives the same nonoptimal
feasible incumbent. The native proof owner spans branches; sibling thinking is
not transferred between branches in any arm. The external grader independently
enumerates four-item sets and checks reachability with BFS. It is not exposed
to the solver. Task bytes, grader, labeling rubric and 32,768-token ceilings
are identical between the retained initial run and the transport-fix run.

| Source | Arm | Input + all output | Submitted optimal branches | Final status |
|---|---|---:|---:|---|
| 0 | baseline | 10,941 | 0 / 6 | Full JSON answer parsing failed |
| 0 | Fact | 14,239 | 0 / 6 | Budget reservation stopped continuation |
| 0 | Scheme | 30,311 | 1 / 6 | Later response incomplete |
| 1 | Scheme | 30,312 | 1 / 6 | Later response incomplete |
| 1 | Fact | 30,312 | 1 / 6 | Later response incomplete |
| 1 | baseline | 30,577 | 1 / 6 | Later response incomplete |

Known solver cost is 146,692 tokens. Cached and replayed input, all thinking,
tool arguments, final text and failed responses are charged. Annotation cost
is separate: 321,371 known tokens across 26 calls, no unknown usage or failed
annotation calls. The initial run retains its two annotation failures. No cell completes the six-branch schedule;
unused allocation is not savings. Source 0's apparent Scheme advantage is
confounded by format failure and reservation censoring in the controls.
Source 1 has the same submitted quality and branch coverage in all arms.
These are two fixtures with one stochastic trajectory per cell, not a causal
performance study. Branch coverage is measured; arbitrary tree depth is not.

## Direct thinking review and measurement limits

Both post-read Scheme responses explicitly consume returned eligibility:
source 0 begins “Confirmed: paths [23,203], [27,207], [31,211], [35,215] are
absent”; source 1 begins “Confirmed invalid items: 2,6,10,14”. They then optimize
remaining choices. In the next sibling, however, source 0 again states the
chain `0->1->2->3->4->5` and derives path `(0,5)` before another read. Native
store availability alone therefore does not deliver evidence before thinking.
The model elected to read late. This is an observable timing boundary, not
proof that native derivations or their admission are incorrect.

The frozen label validator accepts 38 positive derivation spans across two
passes. All were inspected: the stated ordered edge/path chain is visible in
the quote. It rejects 626 candidate labels; no rejection was salvaged.
Same-model passes disagree strongly: for source 1 Scheme, pass 0 accepts
12 derivations in branch 1, whereas pass 1 accepts 20 in branch 0. Missing
paired coverage makes zero cross-branch repeat counts uninterpretable.
`newConsequencesAfterFirst` does not measure deeper search. The generic report's
`withinResponseRepeats` includes consumed-premise labels and must not be read
as a pure repeated-derivation count. `premise_consumed` can also refer to a
conclusion established within that response. Frozen labels are retained as
produced, with these limitations in `literal-review.json`.

The supported conclusion is that evidence delivery and budgeting were repaired,
but repeated thinking reduction and exploration gains remain unproved. A
subsequent preregistered comparison should evaluate evidence observation at
branch entry through this same public binding, preserving source scope and
invalidation, with no behavior-changing anti-repetition prompt. It should also
establish complete paired literal-span coverage before making repeat-rate
claims. Neither change is retroactively applied to these frozen results.

## Reproduction and evidence ownership

Producer commit: `68f9bed1d46ff0e49047efcb74bf6c4c3c3accea`, included in
`source.bundle`. The bundle-based entrypoint has actually completed a fresh
checkout, fresh pinned Gerbil and locked Python dependencies, normal Scheme
compilation, native linking, compiled CFFI API, API/ABI checks, eight consumer
checks, 32 Scheme/Quint observations, sampled Quint checks, Lean `ProofDag`,
and the committed-input freeze gate. All 99 frozen inputs match committed HEAD.

Run `sh reproduce-clean.sh` for the tested local Darwin configuration. Logs
and temporary files are retained on failure; it never calls a model. The
SDK, CPython 3.13, GNU GCC, declared OpenSSL prefix, Quint and Lean are explicit
host prerequisites. Clean local reproduction does not qualify another machine,
a portable wheel, remote CI, or later edits in the primary working tree.

`plan.json` binds tasks, source/API binaries, paper lessons and formal limits.
`qualification-summary.json` and `engineering-raw.tar.gz` retain the rebuild
and test gates. `engineering-failures.json` separates rejected builds from
passes. `raw.tar.gz` contains solver requests, SSE, thinking, real tool packets,
usage and annotations. `audit.json` independently checks the protocol and
scores without calling the provider. `integrity.json` binds published files.
Quint/Lean/native proof checks establish their stated computational scopes;
they do not certify natural-language annotation or model behavior. Agentic AI Lab
retains consumer authority and real temporal trust decisions.

The published `replay.py` was executed in a fresh directory: all archived
source/API identities, paired tool IO, total costs, objective grades, audit
and `report.json` reproduce byte-for-byte without provider calls. Run it with
a compatible Python 3.13 environment containing cffi; its archived binaries
are Darwin-specific. `reproduce-clean.sh` separately rebuilds from source.

Primary checkout consumer tests also pass (8/8), and its locked Python Project
was restored with the declared native-build extra. Two verification invocation
errors and their corrections are recorded in `post-publication-verification.json`.
