# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared snapshot for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json, shutil
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from .. import inference_reuse_study as s
from ._branch_qualification import branch_qualify
from ._config import (
    SHARED_CANDIDATE,
    SHARED_LABEL_TOOL,
    SHARED_QUESTION,
    SHARED_RUBRIC,
    SHARED_TOOL,
)
from ._shared_cases import shared_tasks
from ._shared_qualification import shared_qualify


def shared_freeze(library, directory, *, search_tasks=None):
    directory.mkdir(parents=True, exist_ok=False)
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
    import agentic_ai_lab_runtime.reasoning as evidence_module
    from importlib.util import find_spec
    from ..interface_tests import qualification_inputs, compiled_inputs

    root = s.ROOT.resolve()
    library = Path(find_spec("agentic_ai_lab_runtime._reasoning").origin).resolve()
    dst = directory / library.name
    shutil.copy2(library, dst)
    # Use the installed API extension when available, rather than falling back silently.
    with ReasoningRuntime() as engine:
        qualification = shared_qualify(engine)
        if search_tasks is not None:
            qualification["branchTaskChecks"] = branch_qualify(engine, search_tasks)
    (directory / "qualification.json").write_text(
        json.dumps(qualification, indent=2) + "\n"
    )
    native_receipt = compiled_inputs()
    binding = dict(native_receipt["sourceInputs"])
    # The installed application artifact carries the resolved producer's source
    # digests; qualification_inputs checks the independently installed core wheel.
    names = [
        "gerbil.pkg",
        "packages/python-runtime/pyproject.toml",
        "packages/python-runtime/setup.py",
        "packages/proofs/quint/package.json",
        "packages/proofs/quint/package-lock.json",
        "packages/proofs/lean/lean-toolchain",
    ]
    names += [
        str(p.relative_to(root))
        for p in (
            root
            / "packages/python-testing/src/agentic_ai_lab_testing/assessment_studies"
        ).glob("*.py")
    ]
    names += [
        str(p.relative_to(root))
        for p in (
            root / "packages/proofs/lean/AgenticAILabProof/EvidenceAssessment"
        ).glob("*.lean")
    ]
    names += [
        "packages/proofs/quint/SharedPremiseReuse.qnt",
        "packages/proofs/quint/VerifiedCandidate.qnt",
    ]
    if search_tasks is not None:
        names += [
            "t/research/reproduce-clean.sh",
            "t/research/output-check-fixture.json",
        ]
    for name in names:
        binding[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
    for name, h in binding.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == h, (
            "source drift " + name
        )
        target = directory / "inputs" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target)
    runtime_inputs = qualification_inputs([])
    (directory / "pyo3-runtime-receipt.json").write_text(
        json.dumps(runtime_inputs, indent=2) + "\n"
    )
    (directory / "native-build-receipt.json").write_text(
        json.dumps(native_receipt, indent=2) + "\n"
    )
    metadata = {
        "schema": "ascent.shared-premise-diagnostic.v1",
        "tasks": shared_tasks(),
        "candidate": SHARED_CANDIDATE,
        "question": SHARED_QUESTION,
        "tool": SHARED_TOOL,
        "arms": ["baseline", "facts", "scheme"],
        "orders": [["baseline", "facts", "scheme"], ["scheme", "facts", "baseline"]],
        "model": "deepseek-flash",
        "reasoningEffort": "low",
        "totalBudget": 32768,
        "maxOutputTokens": 32768,
        "minimumOutputTokens": 1024,
        "inputPadding": 256,
        "maxCalls": 3,
        "checkpoints": [4096, 8192, 16384, 24576, 32768],
        "library": library.name,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "inputs": binding,
        "qualificationSha256": hashlib.sha256(
            (directory / "qualification.json").read_bytes()
        ).hexdigest(),
        "annotationRubric": SHARED_RUBRIC,
        "annotationTool": SHARED_LABEL_TOOL,
        "annotationPasses": 2,
        "annotationOutputCap": 8192,
        "annotationRules": "Exact nonoverlapping quotes; endpoint literals; independent finite truth; explicit ordered edge/path chain or ready conjunction for positive inference. premise_consumed must refer to an earlier or supplied true atom. new_residual is derived by classification after validation, never trusted from label name. A repeated positive atom is counted across different questions in the same source scope. Exact-premise repeat reported separately. Negative claims require an explicit negative argument and independently absent atom, but completeness of the quoted absence argument is unproven. Arithmetic and ambiguity are reported without assigning cached-atom savings. Rejected/empty/missing labels remain visible. Two blind passes of the SAME model are correlated annotations, not independent-rater validation.",
        "claims": {
            "correctReuse": "Equal native support nodes across different obligations; source/handle binding and independent answer agreement.",
            "reducedRepetition": "Requires directly supported baseline repetitions plus validated annotation coverage; native hits alone are insufficient.",
            "newInference": "Distinct correct downstream answers and qualified nonsupplied consequences after the first obligation. No optimization or depth claim.",
        },
        "controls": "Same task, sibling schedule, history policy, answer schema and input-plus-all-output cap. No pruning, ranking, optimal answer or anti-repetition instruction. Fact and Scheme supply identical atomic outcomes; Scheme adds checked ancestor-closed fragments. Unused reservations are censored, not savings. All failed calls and unknown usage retained.",
        "sourceState": (
            json.loads((root / ".research-source.json").read_text())
            if (root / ".research-source.json").exists()
            else {
                "head": __import__("subprocess")
                .check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True)
                .strip(),
                "dirtySourceSnapshot": True,
                "cleanCheckoutReproductionVerified": False,
            }
        ),
        "formalToolVersions": {
            "quint": __import__("subprocess")
            .check_output(["quint", "--version"], text=True)
            .strip(),
            "lean": __import__("subprocess")
            .check_output(
                ["lean", "--version"], cwd=root / "packages/proofs/lean", text=True
            )
            .strip(),
        },
        "papers": [
            {
                "id": "BYODS",
                "url": "https://kmicinski.com/assets/byods.pdf",
                "role": "concretization/delta semantics; separate from model efficacy",
            },
            {
                "id": "DatalogBench-v1",
                "url": "https://arxiv.org/html/2609.37233v1",
                "role": "held-out execution and oracle mutation tests",
            },
            {
                "id": "MiniCache-v1",
                "url": "https://arxiv.org/html/2607.20507v1",
                "role": "shared computation with different request variables",
            },
        ],
        "formalBoundary": "SharedPremiseReuse.qnt models finite fixture truth and source-generation admission. ProofDag.lean proves specified ordered positive-DAG soundness under premises, not FFI correctness or model behavior. VerifiedCandidate assumes independent grader validity. Native correspondence receipts are separate.",
    }
    (directory / "plan.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (directory / "plan.sha256").write_text(
        hashlib.sha256((directory / "plan.json").read_bytes()).hexdigest() + "\n"
    )
    report_text(
        "SHARED_PREMISE_FROZEN",
        (directory / "plan.sha256").read_text().strip(),
        flush=True,
    )
