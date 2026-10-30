# Reproducing the shared-premise Library diagnostic

This study is a consumer of the existing Python project and its compiled
`ascent_engine` API. Scheme evaluates and checks evidence; the finite graph
oracle independently grades this small fixture. It does not introduce a
production Python evaluator or a search framework.

## Evidence chain and research status

| Research premise | Implementation | Formal scope | Executable gate | Model claim |
|---|---|---|---|---|
| [BYODS](https://kmicinski.com/assets/byods.pdf): concrete and delta observations agree | `table/storage.ss`, `table/provider.ss`, `program/session.ss` | Existing Provider Lean/Quint models | Existing Provider qualification; separate from this proof-store fixture | Native representation savings do not imply less model thinking |
| [DatalogBench v1](https://arxiv.org/html/2609.37233v1): execution must catch compiling wrong joins | `candidate/reasoning.ss`, `interface/engine-api.ss` | `VerifiedCandidate.qnt` assumes independent grader validity | Diagnostic checks intermediate P as well as ready rows; missing-rule and wrong-join mutants | Frozen finite oracle, not general program equivalence |
| [MiniCache v1](https://arxiv.org/html/2607.20507v1): different requests can share computation | `candidate/evidence-store.ss`; `ComputationalEvidence` in `ascent_engine.evidence` | `SharedPremiseReuse.qnt`: two supports, residual condition, source scope; `ProofDag.lean`: ordered positive-DAG soundness under stated premises | Real API and ABI tests; 32 Scheme/Quint observations; support equality across three obligations; stale/withdrawal/alternative-support checks | Reduction in visible repeated derivation and production of new downstream answers remain empirical |

`EvidenceStore` and `EvidenceChain` retain materialized rows/components.
`ComputationalEvidence` binds the existing native proof store and exposes
`resolve`, `fact`, `fragment`, `stats` and `close`. It is a thin transport:
source identity/generation/content and candidate identity are checked in Scheme.
Unknown evidence remains unknown. JSON candidate strings denote symbols in the
existing bounded candidate DSL; this does not certify natural-language intent.

The model comparison uses baseline, identical Fact outcomes, and those same
outcomes plus Scheme's ancestor-closed fragments. No branch pruning, ranking,
optimal answers or anti-repetition instructions are supplied. Three downstream
obligations share `path(0,2)` and require different residual paths. The third
obligation measures additional correct inference, not optimization quality or
search depth. Two finite sources and one stochastic trajectory per arm/source
are a mechanism diagnostic, not a causal efficacy study.

## Build and qualify

Use the selected checkout and its configured Gerbil SDK/dependencies. The
normal package build owns Scheme compilation; the public linker owns C ABI
assembly. Use fresh build directories and preserve complete failure logs.

```sh
uv sync --project python --locked
gxi build.ss
uv run --project python python -m ascent_engine.build --output "$BUILD/libascent.dylib"
uv run --project python python -m ascent_engine.api_build \
  --library "$BUILD/libascent.dylib" --header bindings/c/ascent.h \
  --out "$BUILD/api" --cc /opt/homebrew/bin/gcc-16
PYTHONPATH="$BUILD/api" uv run --project python python -m unittest \
  discover -s workbench/engine_tests -p test_computational_evidence.py -v
ASCENT_ENGINE_BACKEND=abi ASCENT_ENGINE_LIBRARY="$BUILD/libascent.dylib" \
  uv run --project python python -m unittest \
  discover -s workbench/engine_tests -p test_computational_evidence.py -v
uv run --project python python -m unittest discover \
  -s python/tests -p test_shared_premise.py -v
quint typecheck packages/proofs/quint/SharedPremiseReuse.qnt
quint run packages/proofs/quint/SharedPremiseReuse.qnt \
  --invariants Bound Correct --max-samples 1000 --max-steps 12 --seed 713 --backend typescript
(cd packages/proofs/lean && lake env lean ProofDag.lean)
```

`BUILD` is a caller-selected writable output directory. The displayed compiler
is the one used by this local Darwin qualification; use an explicit installed
GNU GCC supported by the API builder. Linux uses `.so` and needs its own native
qualification. The current extension is not a portable binary wheel.

## Freeze, execute, annotate and replay

All modes live in the existing `ascent_workbench.evidence_chain_study` module.
`PLAN` and `RUN` are fresh caller-selected directories. API mode must be selected
explicitly by placing the receipt-bound extension on `PYTHONPATH`; no fallback
library is loaded. The source and binary identities are checked before and after
execution. A changed producer stops admission.

```sh
export PYTHONPATH="$BUILD/api"
export ASCENT_CFFI_RECEIPT="$BUILD/api/receipt.json"
uv run --project python python -m ascent_workbench.evidence_chain_study \
  shared-freeze "$BUILD/libascent.dylib" "$PLAN"
uv run --project python python -m ascent_workbench.evidence_chain_study \
  shared-check "$PLAN" "$RUN"
uv run --project python python -m ascent_workbench.evidence_chain_study \
  shared-live "$PLAN" "$RUN"
uv run --project python python -m ascent_workbench.evidence_chain_study \
  shared-label "$PLAN" "$RUN"
uv run --project python python -m ascent_workbench.evidence_chain_study \
  shared-report "$PLAN" "$RUN"
```

The freeze consumes the public native build receipt beside the supplied
library. It requires the receipt's Scheme source hashes and rejects source drift
before creating a self-contained snapshot. Source newer than its compiled
module is rejected by the linker; native qualification remains a separate gate.
The complete recipe has not yet been qualified in a clean checkout. The snapshot's `plan.json` contains relative input paths and hashes;
`inputs/` stores those bytes, and `api-runtime/` stores the matching local API.
No pre-existing cache is needed to check or replay a published snapshot. To
replay, restore `inputs/` into a separate checkout, put the snapshot's
`api-runtime/` on `PYTHONPATH`, and run `shared-check` then `shared-report` against
the retained run. Calls are never replayed automatically or charged again.
Rebuilding on another machine and a committed clean-checkout reproduction
remain separate gates; dirty snapshots must retain that status.

`shared-committed-check "$PLAN" "$RUN"` additionally compares every frozen
input with its bytes at `HEAD`, writes the blocked paths and exits 2 on any
uncommitted input. It does not promote local snapshots into clean Git results.

Model credentials are read by the existing provider adapter and never included
in manifests. Each trajectory has a 32,768-token ceiling covering all input,
cached/replayed input and output including thinking. Output reservation is
limited by remaining total budget. A reservation stop is censored; leftover
budget is not savings. Malformed, truncated and failed outputs remain charged.
Annotation costs are separate, including rejected annotations.

The frozen annotation rule requires literal quotes, actual stated support and
independent truth checks. Positive repeats, premise consumption, absence checks,
new consequences, arithmetic and ambiguity are distinguished. Two blind passes
use the same model and are correlated: agreement does not prove completeness
or independent-rater reliability. Native proof soundness does not validate an
LLM-generated annotation. A missing baseline repetition signal is a failed
mechanism measurement, not evidence of zero real repetition.

## Captured execution, 2026-10-11

The [published diagnostic](../docs/research/agent-inference/fact-reuse-results/shared-premise-diagnostic/findings.md) links the formal/native/model gates, source identities, literal thinking evidence, full failures and a `reproduce.sh` entrypoint. Replaying its published archive in a fresh temporary directory passed and produced identical report JSON without provider calls. The captured source is a dirty snapshot at `07c03062b417a95c09e0aadb80b7bc9249fd8102`; current working-tree changes are a separate producer. The committed-input comparison is blocked, not a clean-checkout pass.

All 18 responses were correct and complete. Fact and Scheme increased total input plus output cost on both fixtures. The baseline supplied no reliable cross-question repetition signal; Scheme still rederived supplied premises. Therefore neither reduced repetition nor increased exploration depth/quality is established. Both blind annotation passes, disagreement, rejected labels, and earlier engineering failures remain published. See `findings.md` for the within-question versus cross-question counting caveat.

## Native observation tools and sibling search

The preceding diagnostic shows the model read the supplied fragment and then
said “Let me verify path(0,2) via graph.” The artifact confirms recognition
followed by rechecking; it does not establish a complete account of hidden
model causes. Two observable interaction defects are ordinary user-text
transport rather than evidence tool IO, and ambiguity around “transitions.”

`ComputationalEvidence.observe` projects existing Scheme `fact` / `fragment`
results into named conclusions and support nodes, with the source scope shared
once per packet. Admission, stale-handle checks and inference remain native.
The same Python consumer now exposes `read_paths`; its replies are paired with
actual model calls. Fact and Scheme use the same native conclusions, and only
Scheme includes support. Tool descriptions state capabilities; no instruction
asks the solver to suppress or avoid thinking.

The frozen sibling-search task has sixteen weighted items, pair bonuses,
six branches with different required/excluded items and resource bounds,
and common derived path prerequisites. Each branch forks the same root;
sibling thinking is not transferred between branches in any arm. A retained
native owner spans branches. Every arm gets the same nonoptimal feasible
incumbent. Native qualification independently checks all eligibility rows;
the external grader enumerates all four-item sets and checks paths with BFS.
The grader's optima are absent from solver inputs. One 32,768-token ceiling
covers all sibling inputs and all output, including thinking and failures.
Completed branches and incumbent objective improvement measure exploration
coverage and quality; this fixture does not measure arbitrary tree depth.

`branch-freeze`, `branch-live`, `shared-label` and `branch-report` remain modes
of the existing `ascent_workbench.evidence_chain_study` module. Freezing
requires a clean committed producer and exact source/API identities. The
annotation rule now splits within-response, same-branch and cross-branch
repetitions, and credits supplied evidence only after its tool return. The
two blind passes remain correlated lower-bound annotations.

CFFI compilation in a fresh environment requires
`uv sync --project python --locked --extra native-build`; `setuptools` is now
an explicit optional build dependency instead of an accidental host package.
The published source bundle and `reproduce-clean.sh` perform a clean checkout,
fresh pinned Gerbil dependencies, normal Library compilation, native linking,
public API/ABI tests, formal checks and frozen admission. The recipe never
calls the provider automatically. It requires the qualified local Darwin
SDK, CPython 3.13, GNU GCC, Quint and Lean toolchains; another machine and
remote CI remain separate qualification gates.

The qualified Darwin recipe declares the installed OpenSSL prefix explicitly
(`ASCENT_OPENSSL_PREFIX`, default `/opt/homebrew/opt/openssl@3`) and records
its link flags. The installed SDK embeds an obsolete Cellar library directory;
the first bundle-based link failure is retained. No SDK file is rewritten.

The first sibling run is retained as a failed interaction measurement: Scheme
read tools returned proof data, but byte-counting replayed thinking stopped
both cells before a response could consume it. The existing projection now
publishes shared support nodes once per packet. Continuation reservations use
previous measured input plus all output and a conservative bound for newly
paired tool results, with actual provider usage checked afterward. Tasks,
objective grader, annotation rubric and 32,768-token ceilings remain fixed.
These transport changes do not alter native proof admission.

The completed sibling-search diagnostic is published in
`docs/research/agent-inference/fact-reuse-results/sibling-search/findings.md`.
Clean producer `68f9bed1d46ff0e49047efcb74bf6c4c3c3accea` qualifies all 99
frozen inputs. Both Scheme cells consume actual returned evidence, but no cell
completes six branches. No thinking/depth/quality gain is established. Offline
receipt replay reproduces the audit and report exactly. Annotation coverage
is incomplete and passes disagree; zero repeat counts are not zero repetition.

The next frozen branch-entry comparison sends `ComputationalEvidence.observe`
conclusions in each branch's initial input; Scheme also gets the native DAG.
The task graph, branches and exhaustive grader remain unchanged. All arms
use the same mandatory submission tool, low thinking checkpoint (2,048 output
tokens) and, only on a known reasoning-only truncation, a 256-token non-thinking
submission continuation. No new solver instruction is appended. Truncated
thinking remains censored; successful submission does not certify full reasoning.
A separately costed live output qualification must pass before solver trials.
Only that explicit mode invokes the provider; clean reproduction stays offline
with respect to model calls. Prior input measurements can bound a later sibling
only when all other request/context bytes match; branch changes are charged.
Literal annotation partitions every visible character and retains unresolved
semantic lines. It covers the 38 reviewed reference chains; its limited grammar
does not establish exhaustive natural-language interpretation.

The first live continuation qualification returned a valid submission but only
1,245 input tokens despite the long opaque reasoning history. That did not
establish reasoning consumption. Before any solver comparison, the protocol
was refrozen to project the exact thinking text into an ordinary assistant
message with no added instructions. Live qualification now checks a substantial
input-token increment. This failed evidence boundary and its cost are retained.
Total authorized provider calls remain bounded: two output qualification calls
leave at most 71 solver calls within the original 73-call authorization.

The first six thinking-phase requests were rejected with HTTP 400 because
specific tool_choice is unsupported in thinking mode. All six unknown-usage
failures remain retained. Thinking now uses automatic choice; completed plain
output also receives the common structured non-thinking continuation. The
genuine prior non-thinking qualification is reused only when its exact request,
response, fixture and actual usage validate against the new frozen payload.
After two qualification calls and six rejected solver calls, the remaining
experiment is capped at 65 calls inside the original 73-call authorization.

### Completed branch-entry diagnostic

The source-qualified result and offline replay are published in [branch-entry findings](../docs/research/agent-inference/fact-reuse-results/branch-entry/findings.md). Native evidence is delivered before thinking. Literal reconstruction decreases in the evidence arms; complete reasoning, deeper exploration and a Scheme quality gain remain unestablished. All censored traces, infeasible selections and earlier provider failures are retained.

### Completed thinking and compact packet diagnostic

[Source-qualified branch-complete findings](../docs/research/agent-inference/fact-reuse-results/branch-complete/findings.md) retain the frozen three-arm result. Twelve thinking calls complete naturally; four later calls remain budget-censored and are not salvaged. Scheme first-input tokens drop 27.9% on source 0 through a lossless public binding projection. Fact / Scheme / baseline yield 5 / 4 / 1 optimal submitted branches in the two finite fixtures. Semantic full-coverage gates fail, including a prospectively declared range revision, and all annotation costs and failures remain visible. The complete response/grade/literal/partial-quote evidence replays offline. A subsequent native-negative-premise annotation correction remains a distinct qualification boundary.

The corrected annotation contract is separately source-qualified at 07efe5ae: exact quotes replace model line counts, unreviewed characters remain explicit, and preexposed finite-absent use is distinct from a new absence argument. The cold build passes 20 consumer checks. One retained-trace probe and offline replay validate 12 admitted / 13 rejected proposals; this is a contract smoke, not comprehensive semantic recall or a new solver comparison. The original f6c36359 experiment and both failed full-coverage protocols are unchanged.

The subsequent [contextual semantic review](../docs/research/agent-inference/fact-reuse-results/branch-complete/semantic-review/findings.md) separates positive/negative Fact use from downstream inference and unresolved negative statements. Whole-trace repetition stays unknown. Its existing binding projection and 22 consumer checks reproduce from the supplied clean source bundle; solver quality is not rerun at that source.

## Latest compressed-source round (2026-10-11)

[Results and limitations](../docs/research/agent-inference/fact-reuse-results/branch-compressed/findings.md) bind the model experiment to frozen source `206f465ea75ad6e6d07d8735d094f230bf90176d`. A cold native build, API/ABI checks, scoped formal checks and an offline replay from the bundled source passed. The [replay entry point](../.cache/ascent/archived-runs/docs/research/agent-inference/fact-reuse-results/branch-compressed/replay.py) reproduces native requests, independent grades, costs and semantic admission without provider calls. All failures and truncations remain archived. Unclear or rejected review content does not count as zero repetition; the whole-trace repetition count remains unknown. Under the same per-cell input plus all-output budget, baseline/Fact/Scheme completed 1/5/4 optimal branches respectively. The smaller Scheme evidence input did not improve that count in this diagnostic.
