# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch snapshot for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import copy, hashlib, json
from .. import inference_reuse_study as s
from ._branch_cases import branch_tasks
from ._branch_contracts import branch_candidates
from ._config import (
    BRANCH_QUESTION,
    BRANCH_READ,
    BRANCH_SUBMIT,
    SEMANTIC_BLOCK_TAGS,
    SHARED_LABEL_TOOL,
    SHARED_RUBRIC,
)
from ._shared_check import shared_committed_check
from ._shared_snapshot import shared_freeze


def branch_freeze(library, directory):
    # Reuse the existing source/binary freezer and its native/formal gates.
    tasks = branch_tasks()
    shared_freeze(library, directory, search_tasks=tasks)
    plan = json.loads((directory / "plan.json").read_text())
    plan.update(
        question=BRANCH_QUESTION,
        tasks=tasks,
        tool=BRANCH_SUBMIT,
        readTool=BRANCH_READ,
        experiment="sibling-search",
        maxCallsPerBranch=2,
        evidenceAtBranchEntry=True,
        maxTotalSolverCalls=18,
        artifactDirectory="branch-complete",
        maxOutputTokens=32768,
        requireCompleteThinking=True,
        compactEvidence=True,
        finalizationOutputCap=256,
        annotationMode="literal-partition",
        annotationPasses=1,
        annotationRubric="Frozen literal grammar: arrow chains with at least three nodes; adjacent explicit edge-pair lists; endpoint-preserving via node lists. Truth and direction checked independently. One occurrence per overlapping encoding. All lines partitioned, unresolved semantic lines retained. No unseen premise constructed.",
        annotationTool=None,
        outputProtocol="Automatic tool choice, unchanged low reasoning. Output cap uses all remaining cell budget after conservative input reservation. Never disable thinking to salvage truncation: incomplete first output is a retained censored failure. A completed plain response may use the existing non-thinking structured transport only if its entire replay input and output fit the same total ceiling.",
        annotationCoverage="Every visible character partitioned; only literal ordered chains counted. Unresolved semantic lines retained; syntactic coverage is not exhaustive semantic certification.",
        historyPolicy="Each sibling forks the same root task. No sibling reasoning is imported into another sibling; identical policy in all arms. Native store spans siblings.",
        annotationRules=plan["annotationRules"]
        + " Repetition is split into within-response, same-branch and cross-branch dimensions. Supplied evidence is only evidence returned before the labeled response, never later tool results.",
    )
    plan["independentJudge"] = {
        "algorithm": "Enumerate all four-item subsets independently of Scheme; directed BFS, sum resource constraints, group count and exact pair bonus scoring.",
        "frozenOptima": [
            [max(branch_candidates(t, b))[0] for b in t["branches"]] for t in tasks
        ],
    }
    semantic_tool = copy.deepcopy(SHARED_LABEL_TOOL)
    # Code owns small review blocks. Quotes retain the existing admission rules.
    semantic_tool["parameters"]["properties"]["blocks"] = {
        "type": "array",
        "items": {
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "tags": {
                    "type": "array",
                    "items": {"type": "string", "enum": SEMANTIC_BLOCK_TAGS},
                },
            },
            "required": ["id", "tags"],
            "additionalProperties": False,
        },
    }
    semantic_tool["parameters"]["required"] = ["episodes", "blocks"]
    plan.update(
        semanticTool=semantic_tool,
        maxSemanticCalls=18,
        semanticOutputCap=8192,
        semanticReviewBlockChars=1800,
        semanticRubric=SHARED_RUBRIC
        + " absent_premise_consumed is use of an earlier finite-absent conclusion, not a new absence proof: quote must explicitly refer to native/given evidence; unknown is never an absent premise. Read every supplied reasoningBlock; return each block id exactly once with all applicable tags: positive_fact_use, negative_fact_use, positive_derivation, negative_argument, downstream_inference, optimization, task_interpretation, unclear. Reading or listing supplied conclusions is evidence use, not reconstruction. Applying path facts to item feasibility is downstream inference, not proving those paths again. A negative assertion alone is not an absence argument; unclear use-versus-recheck must include unclear. For episodes, concatenate block texts in their given order and use exact contiguous quotes and zero-based occurrence within that full text. Do not enumerate lines or invent offsets. Do not emit arithmetic episodes. Blocks are review proposals, not certified recall; unsupported or ambiguous content remains unknown. No solver receives these annotation instructions.",
    )
    plan["branchQualification"] = json.loads(
        (directory / "qualification.json").read_text()
    )["branchTaskChecks"]
    # No model trial can begin from a dirty or incomplete producer checkout.
    import subprocess

    status = subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=normal"],
        cwd=s.ROOT,
        text=True,
    )
    assert not status, "clean producer required: " + status
    plan["sourceState"] = {
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=s.ROOT, text=True
        ).strip(),
        "dirtySourceSnapshot": False,
        "cleanCheckoutReproductionVerified": True,
        "scope": "Local clean checkout rebuild and native qualification; not a cross-machine or remote CI claim.",
    }
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    (directory / "plan.sha256").write_text(
        hashlib.sha256((directory / "plan.json").read_bytes()).hexdigest() + "\n"
    )
    shared_committed_check(directory, directory / "committed-gate")
    report_text("BRANCH_FREEZE_OK", flush=True)
