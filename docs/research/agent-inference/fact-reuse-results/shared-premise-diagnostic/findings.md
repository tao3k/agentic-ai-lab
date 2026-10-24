# Research evidence and current finding

The native Library mechanism is qualified on the captured source. This model diagnostic does **not** establish reduced repeated thinking, greater exploration depth, or better answer quality. It is a retained negative/inconclusive result.

| Evidence gate | Result | Limit |
|---|---|---|
| Source and Python project | 99 relative hashed inputs, locked Python dependencies, native source manifest, CFFI producer receipt | Dirty source snapshot at `07c03062b417a95c09e0aadb80b7bc9249fd8102`; later working-tree edits are not qualified by these receipts |
| Quint ↔ Scheme | 32 exact finite observations match; 1,000 sampled traces pass | Finite fixture and sampled checks, not exhaustive verification |
| Lean | `ProofDag.lean` checks with Lean 4.34.0 | Ordered positive-DAG soundness under explicit premises; does not prove model behavior or all source changes |
| Native lifecycle | Nine native/dynamic-module/full-Gxi starts exit cleanly; 448 native plus 448 full-Gxi rule checks and actual public Python API and ABI tests pass | Earlier full-Gxi cleanup timeout is retained; no global runtime repair claim |
| Proof-store mechanism | Same shared-premise support across three downstream questions; one proof build; stale/source-content checks; alternative support and withdrawal checked | Computational evidence, not consumer authority or temporal trust |
| Model execution | 18/18 completed responses independently correct; no truncation, format error, or unknown usage | Two finite sources, one stochastic trajectory per cell; unversioned model alias |
| Literal annotation | Two blind passes, exact quotations and independent finite support validation | Same model in both passes; disagreement and rejected labels; incomplete coverage |
| Published replay | Fresh temporary directory restored from published archive; source/API hashes check; report JSON reproduced byte-for-byte and the public API integration test passes, without provider calls | Same local Darwin CPython/CFFI environment; clean committed build and another machine are separate gates |

## Equal total budget

Every trajectory has a 32,768-token ceiling. All input, replayed/cached input, and all output including thinking count. These three-question schedules finish before the ceiling: remaining tokens are **unused allocation**, not savings or evidence of deeper exploration.

| Source | Baseline | Fact only | Scheme Fact + fragment | Correct answers per arm |
|---|---:|---:|---:|---:|
| 0 | 4,968 | 5,222 | 8,534 | 3/3 |
| 1 | 4,994 | 6,119 | 6,982 | 3/3 |

Solver cost is 36,819 tokens; annotation cost is separately 61,537 tokens, including rejected labels. All calls have recorded usage. At the common 8,192-token checkpoint on source 0, Scheme completes two answers while baseline and Fact complete three; above 8,534 all complete three. There is no quality improvement on this fixture and no total-cost benefit from either evidence arm.

## What the thinking actually supports

The frozen `observedRepeatedFacts` field includes some repetitions within the **same** question. Its rule text describes cross-question repetitions more narrowly. The post-run audit therefore splits these dimensions without changing frozen tasks, labels, or raw receipts. Accepted cross-question positive repetitions are absent in both annotation passes; this is a **missing baseline measurement signal**, not a finding that real repetition is zero. The few accepted repeated `ready(0)` episodes occur within question 0.

Both Scheme trajectories explicitly rederive the already supplied `path(0,2)` on the first question; both passes accept those spans. For example: “Edges: 0->1, 1->2, so path(0,2) holds. Yes.” Providing a sound fragment does not itself cause the model to consume it as established evidence. Later baseline answers already say `path(0,2) yes` without restating a chain, which is premise consumption rather than a qualifying derivation. See [literal evidence](../../../../../.cache/ascent/archived-runs/docs/research/agent-inference/fact-reuse-results/shared-premise-diagnostic/thinking-evidence.md) and the full thinking in `raw.tar.gz`.

Qualified atomic-episode overlap between annotation passes ranges from 0 to 1, with one trajectory having no qualified episodes in either pass. The annotation counts are lower bounds and cannot support a causal reduction claim. Correct later answers measure new downstream inference; this task does not measure search depth or optimization quality.

## Reproduce and inspect

Run `sh reproduce.sh` from this directory in a compatible local Darwin CPython/CFFI environment. The script restores only the published `raw.tar.gz` into a fresh directory, verifies frozen source and API hashes, and regenerates the report without model calls. It compares the resulting report JSON with the published bytes. [Python research instructions](../../../../../python/RESEARCH.md) describe rebuild, API/ABI qualification, formal checks, freeze, execution, annotation, and the strict committed-input gate.

`plan.json` freezes questions, finite independent grader, schema, budgets and annotation rubric. `qualification.json` contains native proof and Quint correspondence. `report.json` and both ledgers retain every solver/annotation outcome. `postrun-audit.json` checks costs, protocol, packet correspondence and repeat scope, and lists the inputs that do not match committed HEAD. `qualification-raw.tar.gz` and `engineering-failures.json` retain build/load/contract failures as distinct engineering evidence. `integrity.json` binds all published files.

The paper-to-Library chain is documented in `python/RESEARCH.md`: Ascent rule/fixed-point semantics and BYODS representation contracts remain the Library's foundation; DatalogBench motivates independent execution checks; program-cache work motivates scoped reuse. Quint models the finite reuse/revision protocol; Lean states proof assumptions; native receipts test implementation correspondence; model outcomes remain empirical. No paper speedup or native cache hit is promoted into a model-thinking claim.
