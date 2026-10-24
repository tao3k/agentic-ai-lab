# Contextual semantic review and native packet projection

This is a post-run, exploratory review of the frozen f6c36359 solver receipts. No task, question, grader, output failure, original annotation verdict or cost is changed. No provider calls were made. Solver quality after the binding change is unmeasured.

The current Library consumer source is `432d2d7fb8073849105de5cb91d649a6a160193f`. Only the existing Python evidence binding, existing research consumer and its regression tests changed relative to 07efe5ae. Native Scheme, candidate rules and scoped Lean/Quint models are unchanged. This is a Python integration qualification against the previously cold-built native library, not a new native cold-build or remote CI claim.

## Semantic distinctions

The existing quote-admission rules remain intact. A supplementary summary now distinguishes positive Fact use, negative Fact use, positive reconstruction proposals, new positive inference proposals and unresolved negative statements. A true absence assertion alone does **not** certify a negative rederivation. Exact quotations and graph truth alone do not certify cognitive inference or annotation recall. Whole-trace repeated derivations, negative rederivations and exploration depth remain `null`, including when there are no admitted quotes. Rejected and unreviewed content cannot become zero repetition.

The prior exploratory atomic proposals are replayed separately from their original failed full-coverage verdict. Their 42 accepted absence statements remain unresolved between evidence use and rechecking. They are not 42 negative proofs. Original quote categories and rejection receipts are preserved.

Eight manually reviewed sections cover the evidence-reading and item-feasibility phases of source 1 / Fact and Scheme / branches 0 and 1. Each exact quotation, offset, trace hash and applicable preexposed positive/negative Fact is recorded in `review.json`. Both arms read the 15 verified and four finite-absent path conclusions and apply the two-path obligation to items. Reading a positive or negative conclusion is Fact use. Deriving item feasibility from those conclusions is downstream reasoning, not reconstructing the paths. No path-proof reconstruction is observed **in these sections**. All other characters and twelve other traces remain unreviewed by this manual review. This is an unblinded analyst review, not independent semantic gold or an exhaustive count.

## Why Scheme completed fewer optimal branches

The difference occurs on source 1: Fact completes three optimal branches; Scheme completes two, then its third thinking is censored. For each attempted branch Scheme pays 2,837 input tokens versus Fact's 1,692, a difference of 1,145. The first two Scheme calls also use 18,377 output tokens versus Fact's 16,798, a difference of 1,579. Consequently the first two branches consume 3,869 more total tokens in Scheme. Its third output reaches its remaining 5,422-token cap and is incomplete; Fact's third output completes in 9,990 tokens. The exact requests, usage and retained thinking are included here.

The larger first-two-output aggregate is not uniform: Scheme's first output is shorter (7,745 versus 9,494), whereas its second is longer (10,632 versus 7,304). Both arms also question the meaning of `start` in their visible reasoning. This is shared task interpretation overhead, not evidence that Scheme rederived a deterministic path. The frozen question is unchanged. The reviewed openings do not unpack proof ancestors. Their larger packet is paid in input even when no proof traversal is visible. These facts locate a budget mechanism; one stochastic trajectory per cell does not establish that the packet caused longer search or that the unseen reasoning is redundant. Completed branch count is not general exploration depth. Unused allocation remains unused, not savings.

## Existing binding improvement

`compact_observation` now references roots already present in the native conclusion only when they match exactly. It also factors the observed relation name for a node kind when all such native nodes actually agree; mixed relations keep their original encoding. `expand_observation` restores all original observations, optional support presence, node order, atoms, rule labels, parents, handles, scope and status. It infers no Fact and removes no proof ancestor. Native absence never receives an invented empty positive proof.

All 12 previously delivered Fact/Scheme native packets round-trip identically. Scheme packets shrink from 3,931 to 3,231 serialized UTF-8 bytes (17.8%); Fact stays 1,191 bytes. The existing branch-entry consumer already uses this public binding helper, so the change reaches its model input without another framework or solver instruction. Provider token reduction and quality at the new source are unknown; byte reduction is not a performance claim.

## Reproduction and retained failures

Run `bash reproduce.sh` in this directory. It clones the exact local source bundle into a fresh checkout, clears the provider key, checks all thinking hashes, reproduces both native encodings, replays the original atomic proposals, verifies the supplementary receipt byte for byte and runs 22 consumer checks. Only Python and Git are required for this offline scope. API and ABI logs additionally record real native-store checks against the prior qualified 07efe5ae build. No new formal claim is made for natural-language annotation.

All 16 original failures/completions remain in the frozen ledger; this directory copies original requests and thinking without repairing truncation. The parent raw archive retains provider responses, independent grades, earlier annotation failures and full costs. New full-trace semantic recall and a real-model quality comparison of this projection remain unqualified.
