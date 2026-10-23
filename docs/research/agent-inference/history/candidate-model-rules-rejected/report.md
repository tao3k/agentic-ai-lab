# Finite Library candidate-feedback gate: qualification denied

The frozen Library build rejects a known-correct positive Datalog proposal before execution. This round made **zero model calls**. Repetition, exploration depth and model quality are **not measured**. The unspent model budget is not savings.

The consumer uses the existing `candidate/reasoning.ss` and `candidate/feedback.ss`. Scheme owns the independent finite-walk oracle and full-row comparisons; Python owns provider IO, records and budget admission. There is no search controller or anti-repetition instruction.

The three frozen tasks are positive-length reachability, positive even-length walks, and the conjunction of reachability from two origins. Each has four visible graphs and 60 held-out graphs on three vertices. A trajectory has 32,768 input plus all-output tokens, including thinking, an 8,192 output cap, and no retries. Only a completed, known-cost proposal failing visible examples can receive the planned paired revision with or without native execution feedback. Shared initial cost is charged to both trajectories. **These model comparisons were not run.**

## Build and observed failure

The Library source closure was consistently captured from the active dirty checkout at 2026-10-11T02:47:50.301380+00:00 (HEAD `652934cd728d7edee32df020af75e9632dffc755`), then built with `std/make`: 62 modules, exit 0. Subsequent workspace edits are outside this frozen build. Source, compiler products, linked C/object files and the executable are hashed in the plan.

A known-correct two-rule transitive-closure proposal is rejected on all four visible graphs: native status `rejected`, feedback `inconclusive`, diagnostic `planner-rejected`. The diagnostic points to the rules contract at `program/types.ss:238`. Even the empty graph is not admitted: empty returned rows are not a semantic match when execution was rejected.

The same public `candidate-program` call through the coherently built dynamic Library also raises a TypeError at that rules contract, with `core/types#yuanxu-contract-validate` in its backtrace. This locates the failure in the captured admission/contract path; it does not yet establish a source fix or a benefit from caching. Full diagnostic: [dynamic-diagnosis.txt](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/dynamic-diagnosis.txt).

The `solve` guard was exercised and refused the frozen plan before provider key lookup or any request. See [qualification.json](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/qualification.json), [correct-control.json](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/correct-control.json), [plan.json](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/plan.json) and [report.json](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/report.json).

## Retained negatives and evidence boundary

Earlier development failures include fixture syntax, omitted nonempty runtime submodules, invalid snapshot identity, a 20-second monolithic qualification timeout, live source drift, batch compilation timeout, macro phase compilation failure and an invalid diagnostic arity. All are retained. The runtime-submodule omission was corrected without widening the deadline. The same 448 reference/mutant checks passed against the earlier prepared build, but source admission rejected that result for the current checkout; it is not evidence for the frozen current build.

The current gate stops at the first correct control. No 448-check success is claimed for this build. No Lean/Quint proof, full DatalogBench reproduction, current-head remote CI, thinking reduction, deeper exploration or quality improvement is claimed. Library admission must pass before the model comparison can be admitted. No shared Library source was reverted or changed by this consumer study.

Raw runtime, captured source, canonical build, all failed attempts, commands and logs are archived with a digest receipt in [archive.json](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/history/candidate-model-rules-rejected/archive.json).
