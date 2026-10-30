# Cross-path fact reuse pilot, eligibility-oracle removal

Frozen plan: `1150d2e7ff106b48b6f16fc2b89c0c951c8f8caaba796e43ef91269aee9f40db`. Six phases; 7 solver calls; 6 blinded annotation calls. All failures retained.

The solver sees seven-stage constrained search. Eligibility requires the conjunction of two graph paths; alternative candidates share these fragments. Two goals reset history and change values, bonuses and resource limits. The native outcome judge independently traverses original edges and exhaustively enumerates plans; it does not read ASCENT proofs or model reasoning.

Gross solver cost includes every input, all output and thinking, including prefix-cache input. Ceiling: 65,536 per phase; measurement calls are separate overhead. Fresh/retained initial packets are byte-identical; baseline gets raw source without an initial packet.

| Arm | Valid submit | Gross tokens | Thinking tokens | Unique candidates | Prefixes | Repeated derivations / extracted derivations | Gaps |
|---|---:|---:|---:|---:|---:|---:|---|
| baseline | 0/2 | 32606 | 20347 | 1 | 2 | 0/30 | [None, 47] |
| fresh | 0/2 | 24012 | 16384 | 0 | 0 | 0/21 | [None, None] |
| retained | 0/2 | 24012 | 16384 | 0 | 0 | 0/28 | [None, None] |

| Task / goal | Arm | Best gap | Prefix depth / full depth | Prefix first-option width | Failure |
|---|---|---:|---:|---:|---|
| no-oracle-shared-search-3 / 0 | baseline | None | 0 / 0 | 0 | output_budget_exhausted |
| no-oracle-shared-search-3 / 1 | baseline | 47 | 4 / 7 | 1 | output_budget_exhausted |
| no-oracle-shared-search-3 / 0 | fresh | None | 0 / 0 | 0 | output_budget_exhausted |
| no-oracle-shared-search-3 / 1 | fresh | None | 0 / 0 | 0 | output_budget_exhausted |
| no-oracle-shared-search-3 / 0 | retained | None | 0 / 0 | 0 | output_budget_exhausted |
| no-oracle-shared-search-3 / 1 | retained | None | 0 / 0 | 0 | output_budget_exhausted |

Direct thinking annotations are in [the span report](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-v2-thinking-annotations.md), including source hashes, character ranges, exact excerpts, prior links and rejected entries. Native fact truth does not prove an annotation’s semantic completeness.

One disjoint fixed task / two task-goal pairs: descriptive instrumentation replay; fixed arm ordering, no statistical or general cognitive claim.
Same packets/control policy in fresh and retained: native cache state alone is not a visible model treatment.
No-evidence baseline may acquire certificates via common fragment tool: initial-packet intervention, not an evidence prohibition.
Same budget ceiling, actual gross input+all output charged; conservative reservation may stop early with unused budget.
Direct annotation is same-provider blinded semantic extraction with exact source spans/native fact truth, not validated exhaustive ground truth or independent-rater agreement.
Arm/outcome metadata are withheld from the annotator, but reasoning content can reveal packet availability; blinding is partial.
This replay changes common source-schema clarification and tool eligibility feedback together; v1 vs v2 is an instrumentation comparison, not an isolated treatment estimate.
Audit instructions identify Fact IDs in every arm and may alter spontaneous reasoning/repetition.
Search depth measures executed prefixes and valid full plans, not an unobserved mental search tree. No hidden reasoning inferred.
Packet-covered rederivation and within-trace duplicates are separate; absent/ambiguous labels do not demonstrate zero repeated thinking.
