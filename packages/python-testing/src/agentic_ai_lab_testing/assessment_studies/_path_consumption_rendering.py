# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Render the complete path study, including unresolved trajectories, source limits and all costs."


def _render_path_report(out, results, audit, partial, stage_costs):
    """Own the render path report phase without weakening its checks."""
    by_run = {r["run"]: r for r in results}
    table = [
        "| Task | Old retained interface | Readable fresh | Readable retained | Old → retained reduction | Fresh → retained reduction |",
        "|------+------------------------+----------------+-------------------+--------------------------+----------------------------|",
    ]
    baseline_total = 0
    fresh_total = 0
    retained_total = 0
    for family in ("balanced", "mutual"):
        a = by_run["baseline-" + family]
        b = by_run["readable-" + family + "-fresh"]
        c = by_run["readable-" + family + "-retained"]
        if not all(
            x["finished"] and x["wholeTaskCorrect"] and x["thinkingComplete"]
            for x in (a, b, c)
        ):
            raise ValueError("primary comparisons must be complete")
        baseline_total += a["thinkingObserved"]
        fresh_total += b["thinkingObserved"]
        retained_total += c["thinkingObserved"]
        table.append(
            f"| {family} | {a['thinkingObserved']} | {b['thinkingObserved']} | {c['thinkingObserved']} | {100 * (1 - c['thinkingObserved'] / a['thinkingObserved']):.2f}% | {100 * (1 - c['thinkingObserved'] / b['thinkingObserved']):.2f}% |"
        )
    table.append(
        f"| Total | {baseline_total} | {fresh_total} | {retained_total} | {100 * (1 - retained_total / baseline_total):.2f}% | {100 * (1 - retained_total / fresh_total):.2f}% |"
    )
    physical_thinking = sum(
        (x.get("usage") or {})
        .get("output_tokens_details", {})
        .get("reasoning_tokens", 0)
        for x in audit.values()
    )
    title = [
        "#+title: Path Consumption, Evidence Reuse, and Whole-Task Reasoning Cost",
        "# SPDX-FileCopyrightText: 2026 tao3k team and Contributors",
        "# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later",
    ]
    report = (
        title
        + [
            "",
            "* Questions and verified root causes",
            "",
            "The previous study observed correct Scheme evidence followed by omitted supported candidates and increased whole-task thinking. This study asks why the interface did not expose useful candidate-path continuation and whether repairing it preserves quality while reducing actual cumulative reasoning. Findings are bounded to the recorded tasks and provider observations.",
            "",
            "Three concrete design defects were addressed: (1) a generic operation/arguments interface advertised conjunction only as an optional alternative; (2) per-branch provenance repeated large fingerprints and source identities, producing approximately 118 KB for 108 checks; (3) native component reuse was not exposed as a convenient model-side path reference and extension operation. These are confirmed interface properties, not a proof of what caused every model decision.",
            "",
            "The initial corrective column encoding introduced another defect. The provider-visible reasoning in new-mutual-retained/stage-0-call-1 interpreted the Boolean present array as potentially indicating that every condition was true. It then queried individual flow states again. The raw record retains the complete observation; this report does not treat visible reasoning as a certified reconstruction of all internal cognition. The final interface eliminates the Boolean mask and exposes explicit branch id/status/reference/conditions objects with shared provenance.",
            "",
            "An independent old-interface baseline in the new corpus voluntarily used four-premise branches. Therefore the earlier non-use was not an intrinsic inability to express conjunction, and the optional-field design is not established as the sole cause. Tool-call records, sampling variation, question interpretation and feedback clarity must be considered together.",
            "",
            "* Implemented Library contract",
            "",
            "EvidenceInteraction registers trusted local domain operations. check_branches advertises candidate paths as required lists of model-selected prerequisites. reuse_paths rechecks an existing local path without retyping conditions. extend_paths combines the original path prerequisites with additional model-selected conditions. Source replacement clears references and retained certificates. Scheme evaluates conjunctions and admits source-bound reuse; Python transports arguments and factors repeated metadata. No registered program is a model-written whole-question query.",
            "",
            "The model receives capability schemas and domain definitions, not a task-specific solution recipe. There are no few-shot solved paths, final-query rules, gold answers, forced tool selection, or required tool sequence in model requests. tool_choice remains auto, strict remains false. All provider reasoning output items and paired tool results are preserved. A complete local predicate check never proves that all necessary conditions for the original natural-language task were selected.",
            "",
            "Readable feedback uses ascent.path-feedback.v1. Every path status is an explicit object field; sharedEvidence applies to branches in that group. Unknown remains unknown, including invalid references and unsupported domain operations. No field is omitted from the auditable expanded packet. The 108-branch fixture contracts from 112073 to 32646 serialized bytes, with exact round-trip equality. This is a context-format measurement, not a reasoning-token saving claim.",
            "",
            "* Corpus, source, and scientific scope",
            "",
            "Two new independent tasks use seeds 2026106501 and 2026106502, distinct from the prior study. The first has context-specific balanced paths: matching opening/closing labels, recursive concatenation, supplied epsilon, scoped denied edges, and a changed-source goal involving a bridge. The second has mutually recursive flow/permission, tag-specific blocks, conversions and grants. Each includes 40 opaque job candidates. Structural complexity, all finite sources, the three goal sentences and independent oracle answers are retained in questions.org.",
            "",
            "Every task has three obligations: the original question, a same-intent paraphrase over unchanged sources, and a changed-source question. An answer to the changed-source question cannot repair an earlier-source obligation. A correct answer to the declared identical paraphrase can repair an earlier failure on that exact finite contract. No arbitrary natural-language equivalence theorem is claimed.",
            "",
            "Task design follows the repository's scoped inference and provenance research, with recursive relational semantics grounded in Datafun/Ascent and reasoning/tool interleaving motivated by ReAct. It is not a reproduction of a published benchmark. Random opaque instances reduce direct instance memorization but do not establish training exclusion. A fully mechanized evaluator could solve these finite tasks without a model; the experiment measures model use and composition of external checked evidence.",
            "",
            "* Protocol and matched controls",
            "",
            "Old-interface retained baselines are executed from a frozen host-package snapshot. The first actual response for each new task is replayed identically into new-interface fresh and retained policies. Original question bytes are checked for equality. Every policy charges all first-response thinking, while physical request accounting deduplicates the provider response ID. The same frozen native artifact and independent oracle are used throughout.",
            "",
            "The first corrective column-format pilot is retained separately. After observing its encoding ambiguity, four final readable-interface trajectories were run. This is an adaptive engineering experiment over two instances, not a preregistered efficacy estimate or a large-sample confidence result. The old-to-new retained comparison changes schema, reference capabilities and feedback layout together. The readable fresh-to-retained comparison isolates the native retention policy more narrowly, but subsequent model sampling still differs.",
            "",
            "Provider: deepseek-flash, high reasoning effort, streaming Responses, max_output_tokens=131072; eight calls and three failed final answers per stage. Usage is actual provider output_tokens_details.reasoning_tokens. Whole-task first correctness includes initial inference, all tool rounds, every failure, paraphrase, and source-change rechecking. Repair cost counts calls after a failed independently graded answer; the failed call itself remains in the whole-task prefix. Output-token totals already include reasoning and must not be added to reasoning a second time.",
            "",
            "* Primary whole-task results",
            "",
        ]
        + table
        + [
            "",
            "All six primary trajectories completed all three obligations: 2/2 tasks and 6/6 obligations per policy. No primary final-answer failures occurred, so primary failed-answer repair costs were zero. An already observed real failure is examined separately below. The aggregate old-to-readable-retained reduction reaches the proposed 40–50% range in this two-instance sample; stable population savings are not established.",
            "",
            f"Interface-only fresh thinking totals {fresh_total}, compared with old retained {baseline_total}: {100 * (1 - fresh_total / baseline_total):.2f}% lower overall. However, balanced fresh increased from 48683 to 52501 (+7.84%). A clearer interface alone is not a guarantee of lower cost. Readable retained reduces thinking by 39.33% relative to readable fresh in aggregate. These distinct comparisons must not be combined into one causal claim.",
            "",
            "* Actual mechanism adoption",
            "",
            "Tool logs establish observable multi-premise path checks and explicit reuse_paths calls in the final trajectories. The shared mutual first response already declared four prerequisites per candidate in the old interface, so its adoption cannot be credited to the new schema. New readable trajectories use short-reference rechecks instead of repeatedly sending every prerequisite. This is observable tool use; it does not prove that a returned observation was correctly consumed internally.",
            "",
            "extend_paths is implemented and tested through actual native execution, including rejection when a parent is invalidated or a new prerequisite fails. No final real-model trajectory invoked it. The report does not claim that extension improved model efficacy.",
            "",
            "* Whole-task cost and latency for every run",
            "",
            "| Run | Calls | Accepted goals | Thinking | Failed final answers | Repair thinking | Provider seconds | Native check seconds | Reuse tool calls |",
            "|-----+-------+----------------+----------+----------------------+-----------------+------------------+----------------------+------------------|",
        ]
    )
    for r in results:
        report.append(
            f"| {r['run']} | {r['calls']} | {r['acceptedObligations']}/3 | {r['thinkingObserved']} | {r['failedFinalAnswers']} | {r['repairThinking']} | {r['providerSeconds']:.2f} | {r['nativeToolSeconds']:.3f} | {r['reuseToolCalls']} |"
        )
    report += [
        "",
        "* Real failed-prefix correction",
        "",
        "The actual prior balanced failure omitted two candidates whose required local conditions were already supported. Both repair arms preserve the same complete prefix through that incorrect answer: 115852 thinking tokens, including the 84849-token failed response. Previously checked fragments are revalidated locally; only feedback is supplied, never final candidate answers. The original user question and failure history are preserved.",
        "",
        "Readable feedback repair used one new model response, 1418 additional thinking, and completed the entire task at 117270 thinking. The column-feedback control used one new response, 964 additional thinking, and completed at 116816. Readable repair is 454 tokens more expensive in this matched example. Therefore the readable format does not show a repair-cost improvement over the column control here. Both achieve correction; no new repair tool invocation was required. Compared with the earlier three-call repair (15125 additional tokens), both are cheaper observations, but that earlier comparison is adaptive and not a causal format-only result.",
        "",
        "* Performance diagnosis",
        "",
        "The expensive work was chiefly in provider inference requests and repeated model composition. For the mutual task, old provider seconds were 167.23 and native checks 1.168; readable retained was 97.12 and native checks 1.477. Balanced old provider seconds were 263.91 and native checks 0.924; readable retained was 181.61 and native checks 0.868. More native checks need not mean more thinking. Provider seconds include model serving, network and streaming; they are not a measured GPU compute duration.",
        "",
        "The previous load receipt for this native artifact measured validation/load/runtime initialization at 0.521 s and first native describe request at 0.000889 s. That separates this study's embedded library initialization from multi-minute model requests. It does not close other consumers' DSL expansion or macro-load gates. No SDK rebuild, timeout widening, remote CI wait or forced tool-use prompt was used for this intervention.",
        "",
        "* Independent evidence audit and formal qualification",
        "",
        f"Independent fixed-point oracles audited {sum(r['independentLocalChecks'] for r in results)} exposed supported/contradicted local path verdicts with zero disagreement. This includes replayed and revalidated observations; the count is not a denominator of statistically independent samples. Every final model answer was independently graded against the complete finite result. Unknown outcomes never acquired positive evidence.",
        "",
        "Actual ABI and compiled API suites each pass 17 checks, including local conjunction, path recheck, parent-preserving extension, source invalidation, 128-candidate capacity, provider-call binding, first-correct scope, and lossless explicit feedback. Lean compiles laws that aliases cannot refresh stale evidence and extension cannot discard a false parent. Quint explores 10000 traces of 30 steps at seed 13 and rejects six mutants: unknown pruning, observation admission, stale reference, missing condition, stale reuse, and dropped parent. These are trusted-checker abstraction laws and bounded protocol checks, not a proof of the native compiler, arbitrary intent, or model cognition.",
        "",
        "* Physical provider usage, reproduction, and limits",
        "",
        f"Unique response records in this study: {len(audit)}; known physical thinking: {physical_thinking}; interrupted request streams lacking receipts: {len(partial)}. Shared prefix IDs are deduplicated physically and charged fully to each policy ledger. Repair prefixes from the prior study are included in task cost but not newly incurred expenditure. Cached input tokens and output/input usage are listed independently in results.json; semantic reuse must not be equated with physical prefix caching. No total-dollar saving is inferred.",
        "",
        "Artifacts: [[file:questions.org][complete questions and source tables]], [[file:rounds.org][every round and outcome]], [[file:visible-answers.org][visible final answers]], [[file:results.json][machine-readable metrics]], [[file:provider-audit.json][unique provider usage]], and [[file:../../features/path-consumption-qualification.json][source-bound local qualification]]. All .cache/ascent/path-consumption request/terminal/event files remain retained locally. The frozen old host and column-pilot controller preserve the actual alternative implementations. This report is regenerated with python -m agentic_ai_lab_testing.assessment_studies.path_consumption_report.",
        "",
        "Main limitations: two independent new instances, one prior real failure, adaptive interface correction, no repeated-sampling confidence interval, no real extension invocation, question-interpretation ambiguity, and complete finite benchmark semantics. Registered domain checks and source authenticity remain application responsibilities. A supported declared path is not proof that the model selected every condition needed by the original problem. The observed aggregate reduction does not establish universal or stable 40–50% savings.",
    ]
    (out / "report.org").write_text("\n".join(report) + "\n")
    return physical_thinking, baseline_total, fresh_total, retained_total
