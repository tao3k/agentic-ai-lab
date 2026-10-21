# Cross-path fact reuse pilot

Frozen plan: `2e5464ae5c1230e3ce210217b405bb61c02d9c17ce548b0d227fe0c0b79b079a`. Twelve phases; 27 solver calls; 12 blinded annotation calls. All failures retained.

The solver sees seven-stage constrained search. Eligibility requires the conjunction of two graph paths; alternative candidates share these fragments. Two goals reset history and change values, bonuses and resource limits. The native outcome judge independently traverses original edges and exhaustively enumerates plans; it does not read ASCENT proofs or model reasoning.

Gross solver cost includes every input, all output and thinking, including prefix-cache input. Ceiling: 65,536 per phase; measurement calls are separate overhead. Fresh/retained initial packets are byte-identical; baseline gets raw source without an initial packet.

| Arm | Valid submit | Gross tokens | Thinking tokens | Unique candidates | Prefixes | Repeated derivations / extracted derivations | Gaps |
|---|---:|---:|---:|---:|---:|---:|---|
| baseline | 0/4 | 76076 | 42094 | 2 | 6 | 0/4 | [226, None, 66, None] |
| fresh | 1/4 | 84097 | 37436 | 3 | 10 | 0/12 | [None, 166, 104, 66] |
| retained | 2/4 | 82533 | 29290 | 5 | 9 | 0/9 | [226, 214, 36, 24] |

| Task / goal | Arm | Best gap | Prefix depth / full depth | Prefix first-option width | Failure |
|---|---|---:|---:|---:|---|
| shared-cert-search-1 / 0 | baseline | 226 | 0 / 7 | 0 | output_budget_exhausted |
| shared-cert-search-1 / 1 | baseline | None | 0 / 0 | 0 | output_budget_exhausted |
| shared-cert-search-1 / 0 | fresh | None | 1 / 0 | 2 | output_budget_exhausted |
| shared-cert-search-1 / 1 | fresh | 166 | 2 / 7 | 2 | output_budget_exhausted |
| shared-cert-search-1 / 0 | retained | 226 | 2 / 7 | 2 | output_budget_exhausted |
| shared-cert-search-1 / 1 | retained | 214 | 2 / 7 | 1 | output_budget_exhausted |
| shared-cert-search-2 / 0 | retained | 36 | 1 / 7 | 2 | none |
| shared-cert-search-2 / 1 | retained | 24 | 3 / 7 | 2 | none |
| shared-cert-search-2 / 0 | fresh | 104 | 2 / 7 | 1 | output_budget_exhausted |
| shared-cert-search-2 / 1 | fresh | 66 | 4 / 7 | 3 | none |
| shared-cert-search-2 / 0 | baseline | 66 | 1 / 7 | 2 | output_budget_exhausted |
| shared-cert-search-2 / 1 | baseline | None | 2 / 0 | 2 | output_budget_exhausted |

Direct thinking annotations are in [the span report](../../../.cache/ascent/archived-runs/docs/research/agent-inference/crosspath-thinking-annotations.md), including source hashes, character ranges, exact excerpts, prior links and rejected entries. Native fact truth does not prove an annotation’s semantic completeness.

Two fixed tasks / four task-goal pairs: descriptive pilot; no statistical or general cognitive claim.
Same packets/control policy in fresh and retained: native cache state alone is not a visible model treatment.
No-evidence baseline may acquire certificates via common fragment tool: initial-packet intervention, not an evidence prohibition.
Same budget ceiling, actual gross input+all output charged; conservative reservation may stop early with unused budget.
Direct annotation is same-provider blinded semantic extraction with exact source spans/native fact truth, not validated exhaustive ground truth or independent-rater agreement.
Arm/outcome metadata are withheld from the annotator, but reasoning content can reveal packet availability; blinding is partial.
Audit instructions identify Fact IDs in every arm and may alter spontaneous reasoning/repetition.
Search depth measures executed prefixes and valid full plans, not an unobserved mental search tree. No hidden reasoning inferred.
Packet-covered rederivation and within-trace duplicates are separate; absent/ambiguous labels do not demonstrate zero repeated thinking.
