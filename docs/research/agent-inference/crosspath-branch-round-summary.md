# Branch reuse experiment: output repair passed; cognitive benefit remains unproved

The v4 local-branch protocol completed **77 real solver calls without output truncation or malformed actions**, after three deep-branch calibration calls also completed. The common feasible seed was independently verified and strictly non-optimal. Every phase retained a valid controller incumbent; none reached the hidden exhaustive optimum. The v3 failed-control experiment remains separately preserved with **15 truncated solver calls**.

All arms have the same 65,536 input + all-output ceiling, including thinking, cached/repeated inputs and failures. Unused budget is **unused**, never token savings. The main comparison below uses the same **32,768 gross-token checkpoint**, only completed expansions and labels from calls ending before that boundary. A seeded full candidate is not an explored seven-layer path.

| Arm / goal | Best value (gain over seed) | Expanded branches | Admitted depth | Labeled positive repeats | Within-chunk / cross-chunk links |
|---|---:|---:|---:|---:|---:|
| baseline / 0 | 303 (+79) | 11 | 7 | 11 | 2 / 9 |
| baseline / 1 | 334 (+90) | 11 | 7 | 20 | 2 / 18 |
| fresh / 0 | 284 (+60) | 6 | 6 | 10 | 3 / 7 |
| fresh / 1 | 349 (+105) | 7 | 7 | 6 | 1 / 5 |
| retained / 0 | 295 (+71) | 6 | 6 | 7 | 1 / 6 |
| retained / 1 | 349 (+105) | 6 | 6 | 11 | 3 / 8 |

The evidence arms have lower extracted positive-repeat counts at common spend, but also execute fewer branch expansions. Their quality improves on one goal and declines on the other relative to baseline. Depth is equal or lower at the matched checkpoint. The experiment **does not establish a reliable improvement in repeated thinking, exploration depth or quality**. Whole-phase thinking totals cannot be called savings because actual spend/call counts and unused budget differ.

Whole-phase annotation encountered 6 failed measurements across the two versions. These remain archived. A separate operational measurement froze two-consecutive-call chunks and matching rules before any bounded extraction. All 40 chunks completed; 437 labels passed byte/schema/span checks, 52 were rejected. The original pre-solver semantic rubric was unchanged. Exact spans/native conclusion truth do **not** establish exhaustive extraction, correct semantic classification or independent-rater agreement. The annotator uses the same provider with partial blinding.

A retrospective literal-ID/boundary audit flagged 11 accepted entries where the annotated Fact ID did not appear among explicit Fact IDs in the quoted span. Some span boundaries include the following Fact heading; one clear case labels the paths 4→11 and 5→9 as F2 while the source text calls them fragment 4. Such corrections/ambiguities prevent interpreting the raw counts as validated cognitive ground truth. Original labels and both snippets are kept. See the JSON diagnostics; this audit does not silently replace the frozen count.

Fresh and retained receive identical model-visible proof packets and policy. Their thinking/quality differences are stochastic descriptions, not a native-cache cognitive effect. Across two goals, fresh builds the native packet twice; retained once and reuses it once. This establishes native proof-work reuse only. The baseline shares the feasible seed, which itself implies some eligibility; it has no initial ASCENT packet rather than no evidence of any kind.

Cost ledger: solver 623,911; disjoint calibration 16,419; original annotation 382,878; bounded annotation 269,971; total 1,293,179 gross tokens. Measurement tokens are separate overhead and never credited to solver savings. Native timings cover packet proofs only, not an end-to-end speed claim.

All raw failed responses, incomplete reasoning, invalid prefixes/completions, malformed annotation JSON, rejected quotes, proof-store receipts and native scores remain in portable archives. Current candidate source bytes match the inherited frozen kernel; source/artifact hashes and initial arm-input parity were verified. This does not certify the entire concurrent working tree or remote CI. Twelve focused tests passed.

- [Frozen v4 protocol](crosspath-branch-v4-protocol.md)
- [V4 native outcomes and original failed measurements](crosspath-search-v4-report.md)
- [Bounded extraction report and ledger](crosspath-search-v4-bounded-report.md)
- [Exact thinking spans and prior links](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-v4-bounded-thinking-annotations.md)
- [V3 failed-control trial](crosspath-search-v3-report.md)
- [Machine-readable summary and retrospective diagnostics](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-branch-round-summary.json)

The next useful system hypothesis is source-bound, branch-specific Fact/proof lookup with a small typed reference, rather than replaying the full proof packet at every expansion. It needs a new frozen experiment; this round provides no positive claim for that untested design.
