# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Render frozen compound inference outcomes, failures and cost accounting."

import json


def _render_mechanism_costs(audit, lines, receipt, prefix):
    """Own the render mechanism costs phase without weakening its checks."""
    for arm, g in audit["groups"].items():
        lines.append(
            f"- {arm}: {g['evidenceAdoption']}/{g['trajectories']} trajectories published Scheme evidence; {g['aliasExtensionQueries']} later queries explicitly extended a published alias."
        )
    exposed = sum(e["laterCallsExposedToEvidence"] for e in audit["episodes"])
    hits = sum(e["completedPathHits"] for e in audit["episodes"])
    lines.extend(
        [
            "",
            f"Later model calls exposed to published evidence: {exposed}. Completed retained-path hits: {hits}. Exposure is not proof that the model causally used each item. Adoption is self-selected; a treatment-only subset is descriptive, not a randomized causal estimate. Without explicit alias extension or a separate execution-only ablation, lower thinking cannot be attributed specifically to cross-round reuse rather than query execution assistance. The experiment does not identify exact redundant internal token spans.",
            "",
            "## Resource accounting",
            "",
            f"Total provider calls: **{receipt['providerCalls']}**. Conservative peak-price estimate: **USD {receipt['peakEstimateUsd']:.6f}**. Under the published weekend off-peak rates, the same usage prices at approximately **USD {receipt['peakEstimateUsd'] / 2:.6f}**; no invoice or account balance was retrieved. Prices: USD 0.30/M uncached input, 0.006/M cached input and 1.20/M output at peak, half off-peak. [Official pricing](https://api-docs.deepseek.com/quick_start/pricing/). Token usage, rather than visible answer byte count, is the basis. Scheme semantic reuse and provider prefix caching are separate mechanisms.",
            "",
            "## Interpretation and limitations",
            "",
            "These are four synthetic compound questions with two trials per condition, not a population accuracy estimate or an independently annotated real-world benchmark. Development choices are known; freezing prevents outcome-adaptive rewriting of these primary trials but does not create an external held-out benchmark. An execution-capable agent baseline would be needed to assess how much benefit is specific to ASCENT. A stable 40–50% claim needs preserved quality, repeated independent workloads and an ablation isolating retained evidence. Source withdrawal and semantic mutation controls passed offline; those controls are not additional paid model tasks.",
            "",
            "The actual frozen CFFI engine executed the evidence. Existing Lean/Quint correspondence qualifies bounded operator and reuse conditions; it does not prove natural-language intent, hidden thinking, arbitrary compilation or empirical token savings. Fresh-source Ubuntu CI is a distinct gate.",
            "",
            "## Evidence files",
            "",
            f"- [Frozen plan]({prefix}-thinking-plan.json)",
            "- [Offline Scheme/oracle qualification](compound-thinking-qualification.json)",
            f"- [Real-model receipt]({prefix}-thinking-result.json)",
            f"- [Audited cumulative costs and pairs]({prefix}-thinking-audit.json)",
            "",
            f"Requests and responses are retained under `.cache/ascent/movie-study/{'compound-thinking-tools-validated-real-20261010' if prefix == 'tool' else 'compound-thinking-real-20261010'}/`; the tracked artifact manifest includes their identities. Frozen outcomes and costs are unchanged.",
            "",
        ]
    )


def _render_failure_feedback(audit, lines, pct):
    """Own the render failure feedback phase without weakening its checks."""
    lines.extend(
        [
            "",
            f"Jointly verified pairs: **{audit['jointlyVerifiedPairs']}/{audit['totalPairs']}**. Measurable thinking pairs: {audit['measurableThinkingPairs']}. Weighted cumulative thinking reduction on that measurable subset: **{pct(audit['jointlyVerifiedThinkingReduction'])}**. Positive means less thinking; negative means more. Read this subset together with full-condition accuracy and censored consumed costs; it does not erase failed trajectories.",
            "",
            "## Failure and repair costs",
            "",
            "| Condition | Failed attempts | Failure + repair calls | Failure + repair thinking | Peak-price estimate USD |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    for arm, g in audit["groups"].items():
        lines.append(
            f"| {arm} | {g['failureAttempts']} | {g['failureAndRepairModelCalls']} | {g['failureAndRepairReasoningTokens']:,} | {g['failureAndRepairPeakEstimateUsd']:.6f} |"
        )
    lines.extend(
        [
            "",
            "Failure + repair includes the first failed attempt and every later call until verification or censoring. It is a measured suffix cost, not proof that every token was avoidable. Ordinary successful evidence-building before a failure remains charged in the trajectory total. Adaptive follow-up costs, when present, are reported separately and never overwrite this frozen phase.",
            "",
            "### Observed failure feedback",
            "",
        ]
    )
    for e in audit["episodes"]:
        for failure in e["failureDetails"]:
            feedback = json.dumps(failure["feedback"], ensure_ascii=True).replace(
                "|", "\\|"
            )
            lines.append(
                f"- {e['case']}, trial {e['repetition'] + 1}, {e['arm']}, turn {failure['turn']}: {failure['outcome']}; thinking {failure['thinkingTokens']}; feedback `{feedback}`."
            )


def _render_paired_outcomes(plan, audit, lines, pct):
    """Own the render paired outcomes phase without weakening its checks."""
    for e in audit["episodes"]:
        lines.append(
            f"| {e['case']} | {e['repetition'] + 1} | {e['arm']} | {'Yes' if e['effort']['verified'] else 'No: censored'} | {e['effort']['modelCalls']} | {e['effort']['observedReasoningTokens']:,} | {' → '.join(e['actions'])} |"
        )
    lines.extend(
        [
            "",
            "## Results by question family",
            "",
            "| Family | Control verified | Scheme verified | Control thinking | Scheme thinking | Reduction on jointly verified trials |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )
    for case in plan["cases"]:
        values = [e for e in audit["episodes"] if e["case"] == case["name"]]
        grouped = [[e for e in values if e["arm"] == arm] for arm in plan["arms"]]
        joint = {
            p["repetition"]
            for p in audit["pairs"]
            if p["case"] == case["name"]
            and p["bothVerified"]
            and p["thinkingReduction"] is not None
        }
        thinking = [
            sum(e["effort"]["observedReasoningTokens"] for e in g) for g in grouped
        ]
        matched = [
            sum(
                e["effort"]["observedReasoningTokens"]
                for e in g
                if e["repetition"] in joint
            )
            for g in grouped
        ]
        reduction = 1 - matched[1] / matched[0] if matched[0] else None
        counts = [sum(e["effort"]["verified"] for e in g) for g in grouped]
        lines.append(
            f"| {case['family']} | {counts[0]}/{len(grouped[0])} | {counts[1]}/{len(grouped[1])} | {thinking[0]:,} | {thinking[1]:,} | {pct(reduction)} ({len(joint)} pairs) |"
        )
    lines.extend(
        [
            "",
            "## Matched thinking reductions",
            "",
            "| Question | Trial | Both verified | Thinking reduction | Turn reduction |",
            "|---|---:|---|---:|---:|",
        ]
    )
    for pair in audit["pairs"]:
        lines.append(
            f"| {pair['case']} | {pair['repetition'] + 1} | {'Yes' if pair['bothVerified'] else 'No'} | {pct(pair['thinkingReduction'])} | {pct(pair['modelTurnReduction'])} |"
        )
    _render_failure_feedback(audit, lines, pct)


def render_report(plan, audit, receipt, *, prefix="compound", include_questions=True):
    def pct(value):
        return "Undefined (unverified pair)" if value is None else f"{value * 100:.2f}%"

    lines = [
        "# Complex reasoning with Scheme evidence: real multi-round comparison",
        "",
        "## Research objective",
        "",
        "Measure whether source-bound Scheme evidence reduces cumulative model thinking to the first independently verified correct answer on four compound questions. The model reasons about each complete question; Scheme checks externally expressed derivations and retains evidence for later reasoning. Subproblem-first planning is not required.",
        "",
        "## Experiment plan and boundaries",
        "",
        f"Four frozen synthetic questions, two trials per condition, {len(audit['episodes'])} trajectories, at most {plan['maxTurns']} turns per trajectory. Both conditions can scan the same raw facts. Each source contains 96 Actors, 32 Films, 8 Directors, 4 Countries and 391 facts. Entity IDs are opaque. Trials start fresh; these are repeated cold trials, not free warm-cache trials.",
        "",
        "Control reasons over raw facts. Assistance additionally has executable claim checking, evidence publication and source-bound alias reuse. No mandatory first-round query or evidence-use gate for a correct answer. Private gold programs, values and counts are excluded from requests. Verification returns only verified/not_verified. Incorrect actions and answers consume turns; no automatic paid retry or post-hoc primary-score replacement.",
        "",
        f"Requested model: deepseek-flash; reasoning effort: high; output ceiling: {plan['maxOutputTokens']:,} per call. Frozen plan SHA-256: `{audit['planSha256']}`. Runtime artifact SHA-256: `{plan['librarySha256']}`.",
        "",
        "## Complete questions",
        "",
    ]
    if include_questions:
        for case in plan["cases"]:
            lines.extend(["### " + case["family"], "", case["question"], ""])
    else:
        lines.extend(["The complete questions above are unchanged in this phase.", ""])
    lines.extend(
        [
            "## Accuracy and total consumed work",
            "",
            "| Condition | Verified / trajectories | Accuracy | First submitted answer correct / assigned | Model calls | Thinking tokens | Input tokens | Output incl. thinking | Scheme/local action seconds |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for arm, g in audit["groups"].items():
        lines.append(
            f"| {arm} | {g['verified']}/{g['trajectories']} | {g['accuracy'] * 100:.1f}% | {g['firstAnswerCorrect']}/{g['trajectories']} | {g['modelCalls']} | {g['consumedReasoningTokens']:,} | {g['consumedInputTokens']:,} | {g['consumedOutputTokens']:,} | {g['schemeSeconds']:.4f} |"
        )
    lines.extend(
        [
            "",
            "All consumed work includes unsuccessful trajectories. Usage completeness is recorded in the audit. Thinking tokens are a subset of output tokens, not an extra billable amount. Local action time includes scans, oracle grading and failed action handling as well as Scheme queries; it is not pure engine compute time. Runtime initialization and pre-turn store admission are outside that timer.",
            "",
            "## First-correct trajectories",
            "",
            "| Question | Trial | Condition | Verified | Calls through first correct / censoring | Thinking tokens | Observable actions |",
            "|---|---:|---|---|---:|---:|---|",
        ]
    )
    _render_paired_outcomes(plan, audit, lines, pct)
    lines.extend(["", "## Evidence mechanism audit", ""])
    _render_mechanism_costs(audit, lines, receipt, prefix)
    return "\n".join(lines)
