<!-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors -->
<!-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -->

# Fresh Repository Evidence Study

## Objective and current status

Evaluate whether snapshot-bound Scheme evidence reduces repeated model reasoning
on genuinely sourced repository problems. The primary measure remains cumulative
provider-reported thinking tokens through the first independently verified correct
solution, including unsuccessful attempts and repairs. Shorter final answers are
not evidence of reduced reasoning work.

This document records source qualification and the evaluation design. Seven public
pull requests were inspected; three fail the temporal admission window. Two surviving
tasks have executable before/after receipts and have entered a real-model pilot.
See the [real repository experiment report](real-repository-experiment-report.md)
for measured outcomes, execution faults, charged work and uniform continuation.
The two tasks do not complete four-family coverage or establish a general cost reduction.

See the [task quality and complexity audit](repository-task-quality.md) for
per-obligation test coverage, difficulty limits, grader blind spots and the
distinction between real-task validity and Scheme mechanism relevance.

## Paper transfer

- [SWE-rebench](https://arxiv.org/html/2505.20411v2): collect real issue/fix pairs,
  separate the solution from grading tests, qualify actual failure-to-pass changes,
  preserve passing controls, and report repeated trajectories. We adopt these
  methodological constraints; we do not reuse its published task answers.
- [SWE-rebench V2](https://arxiv.org/html/2602.23866v2): executable environments
  and task-quality checks should work across languages. Our candidate inventory
  therefore records a Rust implementation with Python tests without classifying
  it as a Python-only fix. An executable adapter is still required for that task.
- [LiveCodeBench](https://arxiv.org/abs/2403.07974): continuously refresh problems
  and evaluate temporal slices. Our temporal slice uses first public disclosure,
  not only the date a maintainer merged a fix.

These papers guide collection and evaluation. Real behavior, repository source,
and independently executed tests supply each task's correctness oracle.

## Provenance and exposure boundary

The current discovery window starts at **2026-09-20 UTC**. Metadata dates are
checked against **2026-10-10 12:21:12 UTC**. Record issue creation, PR creation,
commit author and committer dates, merge date, the fixed commit and its first
parent. Commit dates alone do not establish when a problem first became public.

The machine-readable [source audit](../../../.cache/ascent/archived-runs/docs/research/agent-inference/repository-evidence-source-audit.json)
records all seven candidates, exclusions, revision identities, test transitions,
artifact SHA-256 values, and the isolated environment's complete dependency list.

| Candidate | First public disclosure | Decision |
| --- | --- | --- |
| [NetworkX group betweenness ordering](https://github.com/networkx/networkx/pull/8931) | 2026-09-27 | Temporal checks and executable qualification passed |
| [SymPy series root precision](https://github.com/sympy/sympy/issues/30698) | 2026-10-08 | Temporal checks and executable qualification passed |
| [SymPy ODE solution redundancy](https://github.com/sympy/sympy/pull/30702) | 2026-10-08 | Temporal checks passed; execution qualification pending |
| [Pydantic variadic keyword validation](https://github.com/pydantic/pydantic/pull/13954) | 2026-10-08 | Temporal checks passed; statement clarity and compiled-runtime qualification pending |
| [NetworkX effective size normalization](https://github.com/networkx/networkx/pull/8906) | 2026-09-13 | Outside the disclosure window |
| [pytest bound-method fixture discovery](https://github.com/pytest-dev/pytest/issues/6750) | 2020-02-17 | Old problem despite a recent merge |
| [pytest ExceptionInfo strip text](https://github.com/pytest-dev/pytest/issues/12175) | 2024-04-01 | Old problem despite a recent merge |

**Training exposure remains unknown.** A recent public commit may already be in
training, retrieval, or an updated service backend. A dynamic model alias has no
verified immutable training cutoff here. Report temporal provenance and exposure
uncertainty; do not label this corpus proven unseen or contamination-free.

Related follow-up fixes are grouped by root cause rather than counted as
independent problems. Merely renaming entities is not an independent holdout.
Repository, issue, and root-cause clusters are kept together across development
and evaluation splits.

## Actual qualification results

The parent program was tested with the fixed revision's grading test file; the
source implementation stayed at the parent revision. The same selected test
identities were then run at the fixed revision. These are focused qualification
receipts, not complete upstream CI results.

| Task | Parent result | Fixed result | Failure-to-pass | Passing controls |
| --- | --- | --- | --- | --- |
| Group betweenness ordering | 2 failed, 22 passed | 24 passed | 2 | 22 |
| Series root precision | 2 failed, 1 passed | 3 passed | 2 | 1 |

The NetworkX scope is `TestGroupBetweennessCentrality`. The SymPy scope is
`test_issue_30698`, `test_nth_root`, and `test_inversion`. Some assertions are
inside a single test; the table counts test identities, not individual assertions.
One added NetworkX regression already passes at the parent and is therefore a
passing control, not a third failure-to-pass result.

Initial runs with missing dependencies were skipped or failed during collection;
they were rejected as qualification evidence. After installing pinned dependencies
in an isolated environment, both tasks demonstrated semantic assertion failures
before the fix and success after it. Local NetworkX backend-configuration warnings
remain in the raw logs; no alternate backend was requested.

Artifacts are under `.cache/ascent/repository-study/`, with raw JUnit XML, logs,
exit codes, commands, and original source archives. The tracked audit binds their
bytes. This phase used CPython 3.13.12 on macOS; it does not claim Ubuntu CI closure.

## Source-derived task statements

These statements restate upstream failure requirements without supplying the
repair. These two statements have entered the bounded real-model pilot; broader coverage remains open.

**Directed graph order invariance.** Resolve a defect where group betweenness
centrality changes when the same group members are supplied in a different order.
Analyze directed cycles, shortest-path accumulation, disconnected components,
weighted paths, endpoint inclusion, and normalization. Preserve established
behavior while restoring order invariance. Submit a repair and an explanation
grounded in the parent source and observed tests.

**Series root precision.** Resolve a defect where root expansion loses terms
below the requested precision when the input has a nonzero leading exponent.
Account for reciprocal roots, positive fractional roots, multivariate
coefficients, and truncation boundaries. Check consistency with series inversion
and preserve existing root-expansion behavior. Submit a repair supported by
source evidence and executable observations.

Complexity is assessed from interacting obligations and dependency paths, not
patch length. A short repair can require substantial diagnosis, but these two
tasks alone do not demonstrate broad difficult-task coverage. Before freezing the
primary corpus, add independent tasks covering recursive graph effects,
multi-path lifecycle behavior, scoped conditions/negative cases, and symbolic or
numeric boundary interactions. Select tasks before observing model performance.

## One integrated evaluation protocol

1. **Collect and qualify.** Bind disclosure dates, exact source revisions,
   executable grading tests, passing controls, and dependency identities. Review
   statement clarity, test fairness, complexity, and root-cause independence.
2. **Separate model and grader.** Expose only a hashed parent snapshot and the
   reviewed behavioral statement. Keep fixed source, solution diff, post-fix PR
   prose, hidden tests, and experiment reports outside model tools. Do not expose
   git history, PR lookup, or general network access during evaluation. Public
   upstream parent tests remain available. Hidden grading reveals only a bounded
   verdict; observed development-test failures remain ordinary evidence.
3. **Build evidence in Scheme.** The model receives the whole problem and reasons
   naturally. Tool-observed source dependencies, execution outcomes, and explicit
   candidate claims enter a snapshot-bound evidence store. Scheme checks their
   relational consequences and supplies retained evidence in later rounds. It
   does not certify arbitrary Python semantics or perform general symbolic
   algebra. Dynamic-call coverage and unobserved behavior remain unknown; absence
   of an extracted edge is not proof of non-reachability.
4. **Match three conditions.** Compare ordinary source/test tools, the same tools
   plus fresh Scheme execution, and the same tools plus retained Scheme evidence.
   Fresh versus retained Scheme uses identical prompts, tool contracts, result
   references, grading feedback, and complete provider reasoning history. Only
   evidence persistence differs. Counterbalance arm order, repeat independently,
   use new sessions, and record backend identity when available.
5. **Validate and account.** Stop at the first independently accepted repair.
   Charge all preceding calls, including malformed proposals, failed reasoning,
   failed patches, and repairs. Report thinking tokens, input tokens, total output
   tokens including reasoning, calls, elapsed time, checker work, monetary cost,
   success rate, and censored failures. Missing provider usage stays unknown.

The same-task repeat experiment is separate: a valid exact snapshot/task result
may take a verified direct path without a new model call. A changed code or
dependency snapshot must invalidate dependent results. Do not combine this
zero-call repeat benefit with first-solution enhancement.

For jointly successful paired trajectories, report
`1 - retained cumulative thinking / baseline cumulative thinking`, together with
per-task outcomes and the aggregate token-weighted estimate. Report all failed
trajectories separately; they must not appear as inexpensive successful answers.
Repair cost means model work after a rejected solution through acceptance or
termination, and is also included in total work to first acceptance.

## Implementation and remaining gates

`repository_corpus.py` checks disclosure provenance, missing linked issues,
source/test presence, snapshot identity, and actual test transitions. Its
model-payload allow-list excludes grader fields; filesystem isolation remains an
evaluator obligation. `evidence_chain_study.py` labels the existing generated
movie cases as offline mechanism regressions and refuses them as paid primary
experiments. `repository_model_study.py` now supplies bounded source/edit/test tools, matched
Scheme conditions, snapshot-bound syntactic support and independently graded real
model trajectories. `repository_continuation.py` preserves their full histories,
patches, charged effort and reconstructed evidence for uniform adaptive continuation.
This is not a general repository repair evaluator.

The focused local suite passed **13 tests**, including the actual Scheme
cross-round component reuse and source-change invalidation regression. Separate
large-closure qualification exposed the existing 4,096-row wire-source bound;
completed closures need a properly checked composition path before that workload
can be admitted. Increasing timeouts does not address this admission failure.

Existing `RetainedInference.lean` and `RetainedInference.qnt` cover selected
retention/extension laws and bounded withdrawal cases. They do not prove this new
repository collector, code-analysis extraction, or evaluator isolation correct.
The next formal bridge must model snapshot-qualified observations, composition,
and transitive invalidation, and replay matching Scheme observations. No new
Lean/Quint closure is claimed by this source audit.

For a broader primary comparison beyond the two-task pilot: finish independent four-family coverage,
qualify all selected environments, review model/grader separation, resolve the
large retained-closure admission gap, integrate the repository tool adapter, and
freeze the complete experiment. Publish the resulting full report in English
and show the question set and measured results in Chinese on screen.
