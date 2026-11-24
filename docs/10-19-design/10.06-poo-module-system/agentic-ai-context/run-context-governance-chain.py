#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute the end-to-end ORG -> SysML v2 -> Lean 4 DAG -> Quint (TLC + Apalache + ITF Replay) -> SysML run chain (Slices 40-48)."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LAKE_DIR = ROOT / "proofs/ContextGovernance"
DEFAULT_BINDINGS_PATH = HERE / "40-48-source-bindings-v1.json"
PINNED_OPENSYSML_VERSION = "0.10.1"
PINNED_APALACHE_VERSION = "0.62.1"

SUPPORTING_BINDING_PATHS = (
    "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/00-design-map.org",
    "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/run-context-governance-chain.py",
    "proofs/ContextGovernance/lakefile.lean",
    "proofs/ContextGovernance/lean-toolchain",
    "proofs/ContextGovernance/ContextGovernanceAxioms.lean",
    "dev/d2/governance-figures.sysml",
    "dev/d2/governance-illustrations.ts",
)

# Topological order: all ten upstream planes (40-46 + 48-50) compile before capstone 47.
SLICES = [
    (40, "40-context-governance-boundary", "ContextGovernanceBoundary", "GovernanceArchitectureAndDispatchContract", 2, "tlc"),
    (41, "41-epistemic-consolidation-governance", "ContextEpistemicConsolidationGovernance", "EpistemicDispatchAndBoundaryContract", 2, "tlc"),
    (42, "42-multi-repo-multi-agent-declassification", "MultiRepoAgentDeclassification", "MultiRepoDispatchAndBoundaryContract", 2, "tlc"),
    (43, "43-ascent-security-branch-omission-refinement", "AscentSecurityBranchOmissionRefinement", "SecurityBranchDispatchAndBoundaryContract", 2, "tlc"),
    (44, "44-temporal-causal-survival-and-memory-quotient", "TemporalCausalSurvivalMemoryQuotient", "TemporalSurvivalDispatchAndBoundaryContract", 2, "tlc"),
    (45, "45-org-sexpr-gql-candidate-exchange-search", "OrgSexprGqlCandidateExchange", "HybridSearchDispatchAndBoundaryContract", 2, "tlc"),
    (46, "46-durable-agenda-session-sandbox-governance", "DurableAgendaSessionSandboxGovernance", "ControlAxesDispatchAndBoundaryContract", 2, "tlc"),
    (48, "48-progressive-disclosure-and-two-stage-org-repair", "ProgressiveDisclosureAndOrgRepair", "ProgressiveDisclosureDispatchAndBoundaryContract", 2, "tlc"),
    (49, "49-scoped-detour-funflow-concurrent-shared-context", "ScopedDetourFunflowConcurrentContext", "ScopedDetourAndConcurrentSharedContextContract", 2, "tlc"),
    (50, "50-literature-frontier-detour-confinement-and-causal-audit", "DetourTaintConfinementAndCausalAudit", "LiteratureAbsorptionDispatchAndBoundaryContract", 2, "tlc"),
    (51, "51-memory-poisoning-quarantine-and-kv-prefix-serialization", "MemoryQuarantineAndKvPrefixSerialization", "MemoryQuarantineAndKvPrefixContract", 2, "tlc"),
    (52, "52-funflow-cas-singleflight-and-external-sandbox-binding", "FunflowCasSingleflightAndExternalSandbox", "FunflowCasSandboxDispatchContract", 2, "tlc"),
    (53, "53-yuanxu-c4-profile-convergence-and-interface-slots", "YuanxuC4ProfileConvergence", "YuanxuC4ProfileConvergenceContract", 2, "tlc"),
    (47, "47-end-to-end-context-governance-assurance-closure", "EndToEndContextGovernanceClosure", "EndToEndDispatchAndClosureContract", 4, "apalache"),
]

QUINT_MAINS = {
    "40-context-governance-boundary": "ContextGovernanceBoundary",
    "41-epistemic-consolidation-governance": "ContextEpistemicConsolidationGovernance",
    "42-multi-repo-multi-agent-declassification": "MultiRepoAgentDeclassification",
    "43-ascent-security-branch-omission-refinement": "AscentSecurityBranchOmissionRefinement",
    "44-temporal-causal-survival-and-memory-quotient": "TemporalCausalSurvivalMemoryQuotient",
    "45-org-sexpr-gql-candidate-exchange-search": "OrgSexprGqlCandidateExchange",
    "46-durable-agenda-session-sandbox-governance": "DurableAgendaSessionSandbox",
    "48-progressive-disclosure-and-two-stage-org-repair": "ProgressiveDisclosureAndOrgRepair",
    "49-scoped-detour-funflow-concurrent-shared-context": "ScopedDetourFunflowConcurrentContext",
    "50-literature-frontier-detour-confinement-and-causal-audit": "DetourTaintConfinementAndCausalAudit",
    "51-memory-poisoning-quarantine-and-kv-prefix-serialization": "MemoryQuarantineAndKvPrefixSerialization",
    "52-funflow-cas-singleflight-and-external-sandbox-binding": "FunflowCasSingleflightAndExternalSandbox",
    "53-yuanxu-c4-profile-convergence-and-interface-slots": "YuanxuC4ProfileConvergence",
    "47-end-to-end-context-governance-assurance-closure": "EndToEndContextGovernanceClosure",
}

ALLOWED_STANDARD_AXIOMS = {"propext", "Quot.sound", "Classical.choice"}

STORY_SLUGS = (
    "40-verification-dispatch",
    "42-declassification",
    "43-security-branches",
    "44-causal-survival",
    "45-hybrid-search",
    "46-sandbox-trifecta",
    "47-end-to-end-capsule",
    "48-progressive-disclosure",
    "49-shared-context-detours",
    "50-detour-confinement-audit",
    "51-memory-quarantine-kv-prefix",
    "52-funflow-cas-sandbox",
    "53-c4-profile-convergence",
)

TLC_COUNTS_RE = re.compile(
    r"([\d,]+)\s+states generated,\s+([\d,]+)\s+distinct states found,\s+([\d,]+)\s+states left on queue\."
)
TLC_DEPTH_RE = re.compile(r"The depth of the complete state graph search is (\d+)\.")


def sha256_hex(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def itf_int(v) -> int:
    if isinstance(v, dict) and "#bigint" in v:
        return int(v["#bigint"])
    return int(v)


def itf_set(v) -> list:
    if isinstance(v, dict) and "#set" in v:
        return list(v["#set"])
    return list(v)


def itf_map(v) -> dict:
    if isinstance(v, dict) and "#map" in v:
        return {k: val for k, val in v["#map"]}
    return dict(v)


def project_itf_end_state_to_sysml_scalars(slice_id: int, trace: dict) -> tuple[int, bool, bool, bool, bool]:
    """Project actual final state of a Quint ITF JSON trace into SysML QuintTraceScalarReplayContract inputs.

    Returns (traceSteps, actionConsumed, cutOrGenMatched, grantOrAuthValid, epistemicOrDefeaterSafe).
    """
    states = trace["states"]
    steps = max(0, len(states) - 1)
    last = states[-1]

    if slice_id == 40:
        st = last["s40"]
        ch = st["consumedHandoff"]
        consumed = bool(ch["present"])
        cut_ok = (itf_int(ch["boundCut"]) == itf_int(st["sourceCut"])) and (
            itf_int(ch["effectiveRank"]) <= itf_int(ch["originRank"])
            or itf_int(ch["endorsementCut"]) == itf_int(st["sourceCut"])
        )
        grant_ok = bool(st["grantActive"]) and (
            itf_int(ch["effectiveRank"]) <= itf_int(ch["originRank"])
            or (ch["endorser"] != "" and ch["endorser"] != ch["proposer"])
        )
        epistemic_ok = (st["threatPhase"] != "exposed") and (
            st["threatPhase"] != "accepted" or itf_int(st["residualCut"]) == itf_int(st["sourceCut"])
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 41:
        st = last["s41"]
        recalls = itf_set(st["session2ActiveRecall"])
        promos = itf_set(st["promotedAtRev"])
        live_outs = set(itf_set(st["liveOutcomes"]))
        retr_outs = set(itf_set(st["retractedOutcomes"]))
        consumed = (len(recalls) > 0) or (len(promos) > 0)
        cut_ok = True
        grant_ok = (len(recalls) == 0 or bool(st["session2GrantLive"])) and (
            len(promos) == 0 or bool(st["orgWriteGrantLive"])
        )
        epistemic_ok = all(
            (c["boundOutcome"] in live_outs and c["boundOutcome"] not in retr_outs)
            for c in recalls
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 42:
        st = last["s42"]
        active = itf_set(st["activeDeliveries"])
        revoked = itf_set(st["revokedCerts"])
        direct = set(itf_set(st["directOriginGrants"]))
        consumed = len(active) > 0
        cut_ok = all(
            (not d["viaCert"]) or itf_int(d["cert"]["boundOriginCut"]) == itf_int(st["repoCoreCut"])
            for d in active
        )
        grant_ok = all(
            (d["recipient"] in direct)
            or (
                d["viaCert"]
                and d["recipient"] == d["cert"]["recipient"]
                and d["cert"]["proposer"] != d["cert"]["declassifier"]
                and d["cert"]["recipient"] != d["cert"]["declassifier"]
                and d["cert"]["proposer"] != d["cert"]["recipient"]
                and d["cert"] not in revoked
            )
            for d in active
        )
        epistemic_ok = all(
            (d["recipient"] in direct) or (d["viaCert"] and d["digest"] == "redacted-d1")
            for d in active
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 43:
        st = last["s43"]
        consumed = bool(st["dispatchedDestructiveRemediation"]) or (itf_int(st["dispatchedReadProbes"]) > 0)
        cut_ok = True
        grant_ok = (itf_int(st["dispatchedReadProbes"]) == 0) or bool(st["readGrantWasLiveAtProbe"])
        epistemic_ok = (not bool(st["dispatchedDestructiveRemediation"])) or (
            not bool(st["omissionWasActiveAtRemediation"])
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 44:
        st = last["s44"]
        live_map = itf_map(st["liveStatus"])
        consumed = bool(st["activeCitedGem"]) or bool(st["activeWhyNotGem"])
        cut_ok = st["cut1SnapshotCitedStatus"] == "active"
        grant_ok = (not bool(st["activeWhyNotGem"])) or bool(st["watermarkWasClosedAtWhyNot"])
        epistemic_ok = (not consumed) or (live_map.get("E-cited") == "active")
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 45:
        st = last["s45"]
        receipts = itf_set(st["receipts"])
        tgen = itf_int(st["temporalGen"])
        unique_ok = True
        for i, r1 in enumerate(receipts):
            for r2 in receipts[i + 1 :]:
                if r1["provider"] == r2["provider"] and itf_int(r1["gen"]) == itf_int(r2["gen"]) and r1 != r2:
                    unique_ok = False
        has_gql = any(r["provider"] == "gql" and itf_int(r["gen"]) == tgen and r["complete"] for r in receipts)
        has_asc = any(r["provider"] == "ascent" and itf_int(r["gen"]) == tgen and r["complete"] for r in receipts)
        consumed = bool(st["published"]) or (not unique_ok)
        cut_ok = (not bool(st["published"])) or (itf_int(st["publishedAtGen"]) == tgen and has_gql and has_asc)
        grant_ok = unique_ok
        epistemic_ok = True
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 46:
        st = last["s46"]
        att = st["activeAttempt"]
        consumed = bool(att["consumedFence"])
        cut_ok = (not consumed) or (not bool(att["blindRetryOccurred"]) and bool(att["genStrictlyAdvanced"]))
        grant_ok = (not consumed) or bool(att["wasGrantedAtFence"])
        epistemic_ok = (not (consumed and bool(att["egressEnabled"]))) or (
            not (bool(st["hasUntrustedInput"]) and bool(st["hasPrivateData"]) and not bool(st["egressEndorsed"]))
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 48:
        st = last["s48"]
        pub_s2 = itf_int(st["publishedStageTwoCut"])
        consumed = bool(st["consumedPresent"]) or (pub_s2 != 0)
        cut_ok = (pub_s2 == 0) or bool(st["stageTwoWasValidAtPublish"])
        grant_ok = True
        epistemic_ok = (not bool(st["consumedPresent"])) or (
            (not bool(st["defeaterWasActiveAtConsume"]) or itf_int(st["consumedDepth"]) == 3)
            and (not bool(st["activeDefeaterPresent"]) or itf_int(st["consumedDepth"]) == 3)
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 49:
        st = last["s49"]
        consumed = bool(st["fencedEffectCommitted"]) or bool(st["archived"]) or bool(st["overwrittenByNonOwner"])
        cut_ok = (not bool(st["fencedEffectCommitted"])) or bool(st["fencedEffectWasSafe"])
        grant_ok = not bool(st["overwrittenByNonOwner"])
        epistemic_ok = (
            (not bool(st["archived"]) or not bool(st["archivedWhileUnsafe"]))
            and (itf_int(st["defeatersRetained"]) >= itf_int(st["discoveredDefeaters"]))
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 50:
        st = last["s50"]
        consumed = (
            (itf_int(st["mergedReceiptCount"]) > 0)
            or bool(st["detourEgressAttempted"])
            or bool(st["offlineAuditExecuted"])
        )
        cut_ok = (not bool(st["unattestedMergeOccurred"])) and (not bool(st["mainlineTainted"]))
        grant_ok = (not bool(st["detourEgressAttempted"])) or (not bool(st["detourEgressWasTainted"]))
        epistemic_ok = (
            (
                (not bool(st["offlineAuditExecuted"]))
                or (not (bool(st["decisionFlippedBySecret"]) and not bool(st["auditDeclassCertified"])))
                or bool(st["causalLeakFlagged"])
            )
            and (not bool(st["advisoryAutoMutatedMainline"]))
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 51:
        st = last["s51"]
        consumed = (
            (itf_int(st["recalledCount"]) > 0)
            or bool(st["untrustedAutoPromoted"])
            or bool(st["kvPrefixFractured"])
        )
        cut_ok = (not bool(st["kvPrefixFractured"])) and (itf_int(st["frozenPrefixEpoch"]) == 1)
        grant_ok = not bool(st["untrustedAutoPromoted"])
        epistemic_ok = (not bool(st["recalledPoisonedOrQuarantined"])) and (not bool(st["recallableContainsPoison"]))
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 52:
        st = last["s52"]
        consumed = (
            bool(st["casPublished"])
            or bool(st["archivedWorkflow"])
            or (itf_int(st["activeComputeCount"]) > 1)
            or (itf_int(st["fencedExecCount"]) > 0)
            or bool(st["pinnedEntryEvictedByGc"])
            or bool(st["corruptCasVisible"])
        )
        cut_ok = (itf_int(st["activeComputeCount"]) <= 1) and (not bool(st["corruptCasVisible"]))
        grant_ok = (not bool(st["pinnedEntryEvictedByGc"])) and (
            (not bool(st["capsulePinned"])) or bool(st["casPublished"])
        )
        epistemic_ok = (
            (itf_int(st["fencedExecCount"]) <= 1)
            and (not bool(st["archivedWithDroppedFinalizer"]))
            and ((not (bool(st["archivedWorkflow"]) and bool(st["fencedFailed"]))) or bool(st["finalizerCompleted"]))
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 53:
        st = last["s53"]
        admitted_mods = set(itf_set(st["admittedModules"]))
        left = str(st["peerSlotLeft"])
        right = str(st["peerSlotRight"])
        consumed = (
            bool(st["contextDurableEnabled"])
            or bool(st["contextDurableVetoed"])
            or bool(st["undeclaredModulePulled"])
            or bool(st["conflictDetected"])
            or bool(st["silentPeerOverwrite"])
            or (itf_int(st["runtimeOverlayCount"]) > 0)
            or (itf_int(st["effectiveTrustCeiling"]) != itf_int(st["parentTrustCeiling"]))
        )
        cut_ok = (
            (not bool(st["undeclaredModulePulled"]))
            and ((not bool(st["contextDurableEnabled"])) or ("durable" in admitted_mods))
            and (not bool(st["runtimeExpandedCompile"]))
        )
        grant_ok = (
            ((not bool(st["contextDurableVetoed"])) or (not bool(st["contextDurableEnabled"])))
            and (itf_int(st["effectiveTrustCeiling"]) <= itf_int(st["parentTrustCeiling"]))
        )
        epistemic_ok = (not bool(st["silentPeerOverwrite"])) and (
            (not (left != "" and right != "" and left != right)) or bool(st["conflictDetected"])
        )
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    if slice_id == 47:
        cap = last["c"]
        consumed = bool(cap["hostCasConsumed"])
        cut_ok = (not consumed) or bool(cap["planesWereLiveAtCas"])
        grant_ok = (not bool(cap["coldReplayVerifiedAtCut1"])) or bool(cap["archivedCut1Capsule"])
        epistemic_ok = True
        return steps, consumed, cut_ok, grant_ok, epistemic_ok

    raise RuntimeError(f"Unsupported slice_id for ITF projection: {slice_id}")


def verify_org_and_links() -> dict:
    targets = [HERE / "00-design-map.org"] + [HERE / f"{stem}.org" for _, stem, *_ in SLICES]
    checked = 0
    for org_path in targets:
        if not org_path.exists():
            raise RuntimeError(f"Missing ORG file: {org_path}")
        txt = org_path.read_text(encoding="utf-8")
        if "SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later" not in txt:
            raise RuntimeError(f"Missing SPDX license header in {org_path.name}")
        if org_path.name.startswith("4") and re.search(r"#\+begin_src\s+scheme", txt, re.I):
            raise RuntimeError(f"Forbidden Scheme block in design-only slice {org_path.name}")
        for match in re.finditer(r"\[\[file:([^\]#:]+)", txt):
            rel = match.group(1)
            resolved = (org_path.parent / rel).resolve()
            if not resolved.exists() and "dev/d2/output/org-agentic-inquiry" not in rel:
                raise RuntimeError(f"Broken relative link in {org_path.name}: {rel}")
        checked += 1
    return {"org_files_checked": checked}


def parse_and_audit_sysml_taxonomy(out_dir: Path) -> dict:
    cmd = ["sysml", "-strict", "-validate", "-self-check", "-no-record-cache", str(HERE)]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=False)
    (out_dir / "sysml-validate.log").write_text(res.stdout + res.stderr, encoding="utf-8")
    if res.returncode != 0:
        raise RuntimeError(f"Whole-directory SysML validation failed:\n{res.stdout}\n{res.stderr}")
    m = re.search(
        r"Self-model check:\s*(\d+)\s*elements,\s*(\d+)\s*checks,\s*(\d+)\s*violations,\s*(\d+)\s*unevaluated",
        res.stdout,
    )
    if not m or int(m.group(3)) != 0 or int(m.group(4)) != 0:
        raise RuntimeError(f"Unexpected SysML self-check summary: {res.stdout}")

    req_pattern = re.compile(
        r"requirement\s+(\w+)\s*:\s*(LeanAlgebraicObligation|QuintInterleavingObligation)\s*\{(.*?)\}",
        re.S,
    )
    alloc_pattern = re.compile(r"allocation\s+\w+\s+allocate\s+(\w+)\s+to\s+([\w\.]+)\s*;")

    lean_bindings: list[dict] = []
    quint_bindings: list[dict] = []
    total_reqs = 0

    for slice_id, stem, pkg_name, *_ in SLICES:
        sysml_file = HERE / f"{stem}.sysml"
        text = sysml_file.read_text(encoding="utf-8")
        reqs = {}
        for rmatch in req_pattern.finditer(text):
            rname, rkind, rbody = rmatch.group(1), rmatch.group(2), rmatch.group(3)
            reqs[rname] = (rkind, rbody)
        if not reqs:
            raise RuntimeError(f"SysML slice {sysml_file.name} defines zero classified obligations")

        allocs: dict[str, list[str]] = {r: [] for r in reqs}
        for amatch in alloc_pattern.finditer(text):
            rname, target = amatch.group(1), amatch.group(2)
            if rname not in allocs:
                raise RuntimeError(f"Allocation in {sysml_file.name} references untyped requirement {rname}")
            allocs[rname].append(target)

        for rname, (rkind, rbody) in reqs.items():
            total_reqs += 1
            targets = allocs[rname]
            to_lean = any(t.endswith(".verifierSuite.leanEngine") for t in targets)
            to_quint = any(t.endswith(".verifierSuite.quintEngine") for t in targets)
            to_domain = any(".verifierSuite." not in t for t in targets)
            if to_lean == to_quint:
                raise RuntimeError(
                    f"XOR engine violation in {sysml_file.name}::{rname}: "
                    f"to_lean={to_lean}, to_quint={to_quint}"
                )
            if not to_domain:
                raise RuntimeError(f"Requirement {sysml_file.name}::{rname} lacks domain owner allocation")

            if rkind == "LeanAlgebraicObligation":
                if not to_lean:
                    raise RuntimeError(f"{rname} typed LeanAlgebraicObligation but not routed to leanEngine")
                art = re.search(r'leanArtifact\s*=\s*"([^"]+)"', rbody)
                thms = re.search(r'leanTheorems\s*=\s*"([^"]+)"', rbody)
                if not art or not thms or art.group(1) != f"{stem}.lean":
                    raise RuntimeError(f"Malformed Lean binding in {sysml_file.name}::{rname}")
                names = [x.strip() for x in thms.group(1).split(",") if x.strip()]
                lean_bindings.append(
                    {"slice_id": slice_id, "slice": stem, "namespace": pkg_name, "requirement": rname, "theorems": names}
                )
            else:
                if not to_quint:
                    raise RuntimeError(f"{rname} typed QuintInterleavingObligation but not routed to quintEngine")
                art = re.search(r'quintArtifact\s*=\s*"([^"]+)"', rbody)
                invs = re.search(r'quintInvariants\s*=\s*"([^"]+)"', rbody)
                if not art or not invs or art.group(1) != f"{stem}.qnt":
                    raise RuntimeError(f"Malformed Quint binding in {sysml_file.name}::{rname}")
                names = [x.strip() for x in invs.group(1).split(",") if x.strip()]
                quint_bindings.append(
                    {"slice_id": slice_id, "slice": stem, "main": QUINT_MAINS[stem], "requirement": rname, "invariants": names}
                )

    return {
        "elements": int(m.group(1)),
        "checks": int(m.group(2)),
        "total_classified_requirements": total_reqs,
        "xor_disjoint": True,
        "lean_bindings": lean_bindings,
        "quint_bindings": quint_bindings,
    }


def verify_lean_dag_and_axioms(out_dir: Path, lean_bindings: list[dict]) -> dict:
    lean_build = out_dir / "lean-build"
    lean_build.mkdir(parents=True, exist_ok=True)
    env = dict(**subprocess.os.environ, LEAN_PATH=str(lean_build))

    for _, stem, *_ in SLICES:
        src = HERE / f"{stem}.lean"
        olean = lean_build / f"{stem}.olean"
        res = subprocess.run(
            ["lean", "-R", str(HERE), "-o", str(olean), str(src)],
            cwd=str(LAKE_DIR),
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if res.returncode != 0 or res.stdout.strip() or res.stderr.strip():
            raise RuntimeError(f"Lean compile/warning failure on {src.name}:\n{res.stdout}\n{res.stderr}")

    audit_lines = [
        "-- Auto-generated by run-context-governance-chain.py from SysML v2 FormalVerificationTaxonomy",
        *[f"import «{stem}»" for _, stem, *_ in SLICES],
        "",
    ]
    expected_theorems = []
    for item in lean_bindings:
        ns = item["namespace"]
        for thm in item["theorems"]:
            fq = f"{ns}.{thm}"
            expected_theorems.append(fq)
            audit_lines.append(f"#check @{fq}")
            audit_lines.append(f"#print axioms {fq}")

    audit_file = lean_build / "SysmlLeanChainAudit.lean"
    audit_file.write_text("\n".join(audit_lines) + "\n", encoding="utf-8")
    res = subprocess.run(
        ["lean", str(audit_file)],
        cwd=str(LAKE_DIR),
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )
    (out_dir / "lean-axiom-audit.log").write_text(res.stdout + res.stderr, encoding="utf-8")
    if res.returncode != 0:
        raise RuntimeError(f"SysML -> Lean theorem binding audit failed:\n{res.stdout}\n{res.stderr}")

    axiom_records = {}
    for m_none in re.finditer(r"^'([^']+)' does not depend on any axioms$", res.stdout, re.M):
        axiom_records[m_none.group(1)] = []
    for m_some in re.finditer(r"^'([^']+)' depends on axioms: \[([^\]]+)\]", res.stdout, re.M | re.S):
        axs = [a.strip() for a in m_some.group(2).split(",") if a.strip()]
        disallowed = set(axs) - ALLOWED_STANDARD_AXIOMS
        if disallowed:
            raise RuntimeError(f"Disallowed axioms on {m_some.group(1)}: {sorted(disallowed)}")
        axiom_records[m_some.group(1)] = axs

    for fq in expected_theorems:
        if fq not in axiom_records:
            raise RuntimeError(f"Missing axiom audit output for {fq}")

    return {
        "compiled_modules": len(SLICES),
        "verified_theorems_count": len(expected_theorems),
        "axiom_audit": axiom_records,
    }


def verify_quint_tlc_apalache_and_export_itf(
    out_dir: Path, quint_bindings: list[dict], max_steps: int
) -> tuple[dict, list[dict]]:
    qwork = out_dir / "quint-work"
    itf_root = out_dir / "itf-traces"
    qwork.mkdir(parents=True, exist_ok=True)
    itf_root.mkdir(parents=True, exist_ok=True)

    by_slice: dict[str, set[str]] = {}
    for item in quint_bindings:
        by_slice.setdefault(item["slice"], set()).update(item["invariants"])

    verified_models = []
    itf_records: list[dict] = []

    for slice_id, stem, _, _, _, backend in SLICES:
        qfile = HERE / f"{stem}.qnt"
        main_mod = QUINT_MAINS[stem]
        qtext = qfile.read_text(encoding="utf-8")
        req_invs = sorted(by_slice.get(stem, set()))
        if not req_invs:
            raise RuntimeError(f"Zero Quint invariants bound in SysML for {qfile.name}")

        # Bidirectional traceability check: 100% of `val safety = and { ... }` conjuncts MUST match SysML!
        safety_m = re.search(r"\bval\s+safety\s*=\s*and\s*\{(.*?)\}", qtext, re.S)
        if not safety_m:
            raise RuntimeError(f"Missing `val safety = and {{ ... }}` in {qfile.name}")
        actual_conjuncts = sorted(x.strip() for x in safety_m.group(1).split(",") if x.strip())
        if actual_conjuncts != req_invs:
            raise RuntimeError(
                f"Bidirectional SysML<->Quint invariant mismatch in {qfile.name}: "
                f"SysML={req_invs} vs Quint safety={actual_conjuncts}"
            )
        for inv in req_invs:
            if not re.search(rf"\bval\s+{re.escape(inv)}\s*=", qtext):
                raise RuntimeError(f"SysML invariant {inv} missing definition in {qfile.name}")
        if not re.search(r"\baction\s+buggy\w+", qtext) or "CounterexampleTest" not in qtext:
            raise RuntimeError(f"Missing non-vacuity buggy counterexample witness in {qfile.name}")

        # 1. Typecheck
        tc = subprocess.run(
            ["quint", "typecheck", str(qfile)],
            cwd=str(qwork),
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        (out_dir / f"quint-{stem}-typecheck.log").write_text(tc.stdout + tc.stderr, encoding="utf-8")
        if tc.returncode != 0:
            raise RuntimeError(f"Quint typecheck failed on {qfile.name}:\n{tc.stdout}\n{tc.stderr}")

        # 2. Deterministic witness & counterexample runs + real ITF JSON trace export
        slice_itf_dir = itf_root / stem
        slice_itf_dir.mkdir(parents=True, exist_ok=True)
        itf_pattern = str(slice_itf_dir / "itf-{test}.json")
        tst = subprocess.run(
            ["quint", "test", "--out-itf", itf_pattern, str(qfile), "--main", main_mod],
            cwd=str(qwork),
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )
        (out_dir / f"quint-{stem}-test.log").write_text(tst.stdout + tst.stderr, encoding="utf-8")
        if tst.returncode != 0:
            raise RuntimeError(f"Quint test failed on {qfile.name}:\n{tst.stdout}\n{tst.stderr}")

        # Collect local-module ITF traces (skip imported `s4X::*` duplicates inside 47)
        local_runs = set(re.findall(r"^\s*run\s+(\w+)\s*=", qtext, re.M))
        exported_for_slice = 0
        for itf_path in sorted(slice_itf_dir.glob("itf-*.json")):
            test_name = itf_path.stem.removeprefix("itf-")
            if test_name not in local_runs:
                continue
            exported_for_slice += 1
            trace = json.loads(itf_path.read_text(encoding="utf-8"))
            steps, consumed, cut_ok, grant_ok, epist_ok = project_itf_end_state_to_sysml_scalars(slice_id, trace)
            expect_unsafe = "CounterexampleTest" in test_name
            itf_records.append(
                {
                    "slice_id": slice_id,
                    "slice": stem,
                    "test": test_name,
                    "trace_file": str(itf_path),
                    "trace_sha256": sha256_hex(itf_path),
                    "steps": steps,
                    "consumed": consumed,
                    "cut_ok": cut_ok,
                    "grant_ok": grant_ok,
                    "epist_ok": epist_ok,
                    "expect_unsafe": expect_unsafe,
                }
            )
        if exported_for_slice != len(local_runs):
            raise RuntimeError(
                f"Expected {len(local_runs)} ITF traces for {qfile.name}, exported {exported_for_slice}"
            )

        # 3. Exhaustive TLC (for 40-46, 48) or 8-step Apalache SMT (for 8-plane composed 47)
        if backend == "tlc":
            vcmd = [
                "quint",
                "verify",
                "--backend",
                "tlc",
                "--apalache-version",
                PINNED_APALACHE_VERSION,
                str(qfile),
                "--main",
                main_mod,
                "--invariant",
                "safety",
            ]
        else:
            vcmd = [
                "quint",
                "verify",
                "--apalache-version",
                PINNED_APALACHE_VERSION,
                str(qfile),
                "--main",
                main_mod,
                "--max-steps",
                str(max_steps),
                "--invariant",
                "safety",
            ]

        vres = subprocess.run(
            vcmd,
            cwd=str(qwork),
            capture_output=True,
            text=True,
            timeout=240 if backend == "tlc" else 480,
            check=False,
        )
        vout = vres.stdout + vres.stderr
        (out_dir / f"quint-{stem}-verify-{backend}.log").write_text(vout, encoding="utf-8")
        if vres.returncode != 0 or "[ok] No violation found" not in vout:
            raise RuntimeError(f"Quint {backend} verify failed on {qfile.name}:\n{vout}")

        entry: dict = {
            "slice_id": slice_id,
            "slice": stem,
            "main": main_mod,
            "backend": backend,
            "invariants": req_invs,
            "exported_itf_traces": exported_for_slice,
        }
        if backend == "tlc":
            cm = TLC_COUNTS_RE.search(vout)
            dm = TLC_DEPTH_RE.search(vout)
            if not cm or int(cm.group(3).replace(",", "")) != 0:
                raise RuntimeError(f"TLC did not exhaust queue (queue != 0) on {qfile.name}:\n{vout}")
            entry["generated_states"] = int(cm.group(1).replace(",", ""))
            entry["distinct_states"] = int(cm.group(2).replace(",", ""))
            entry["queue_remaining"] = 0
            entry["graph_depth"] = int(dm.group(1)) if dm else None
        else:
            entry["max_steps"] = max_steps

        verified_models.append(entry)

    return {"verified_models": verified_models}, itf_records


def replay_verdicts_and_itf_traces_into_sysml(
    out_dir: Path, *, lean_ok: bool, quint_ok: bool, xor_ok: bool, itf_records: list[dict]
) -> dict:
    b_lean = "true" if lean_ok else "false"
    b_quint = "true" if quint_ok else "false"
    b_xor = "true" if xor_ok else "false"

    base40 = str(HERE / "40-context-governance-boundary.sysml")
    all_files = [str(HERE / f"{stem}.sysml") for _, stem, *_ in SLICES]

    dispatch_executed = []
    for _, stem, pkg, verif_def, neg_count, _ in SLICES:
        files = all_files if stem.startswith("47-") else sorted({base40, str(HERE / f"{stem}.sysml")})
        cases = [(f"{pkg}::{verif_def}({b_lean},{b_quint},{b_xor},true,0)", False)]
        if neg_count == 2:
            b4_mode2 = "true" if stem.startswith(("43-", "46-")) else "false"
            b3_mode1 = "true" if stem.startswith("40-") else "false"
            cases.append((f"{pkg}::{verif_def}(true,true,{b3_mode1},true,1)", True))
            cases.append((f"{pkg}::{verif_def}(true,true,true,{b4_mode2},2)", True))
        else:
            cases.extend(
                [
                    (f"{pkg}::{verif_def}(false,true,true,true,1)", True),
                    (f"{pkg}::{verif_def}(true,false,true,true,2)", True),
                    (f"{pkg}::{verif_def}(true,true,false,true,3)", True),
                    (f"{pkg}::{verif_def}(true,true,true,false,4)", True),
                ]
            )

        cmd = ["sysml", "-strict", "-no-record-cache", *files, "-engine", "run", "-json"]
        for subj, _ in cases:
            cmd += ["-analysis", subj]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=False)
        (out_dir / f"sysml-dispatch-{stem}.json").write_text(res.stdout, encoding="utf-8")
        payload = json.loads(res.stdout)
        checks = payload.get("checks") or []
        if payload.get("errors") or len(checks) != len(cases):
            raise RuntimeError(f"SysML JSON dispatch error on {stem}: {res.stderr}")

        for (subj, expect_fail), chk in zip(cases, checks):
            expected_status = "fails" if expect_fail else "holds"
            expected_kind = "fail" if expect_fail else "pass"
            verdicts = chk.get("verifications") or []
            if (
                chk.get("subject") != subj
                or chk.get("status") != expected_status
                or len(verdicts) != 1
                or verdicts[0].get("kind") != expected_kind
            ):
                raise RuntimeError(f"Unexpected SysML dispatch verdict for {subj}: {chk}")
            dispatch_executed.append({"subject": subj, "expected_unsafe": expect_fail, "status": chk.get("status")})

    # Real Quint ITF JSON trace replay into SysML QuintTraceScalarReplayContract
    replay_cases = []
    cmd = ["sysml", "-strict", "-no-record-cache", *all_files, "-engine", "run", "-json"]
    for rec in itf_records:
        b = lambda x: "true" if x else "false"
        subj = (
            f"EndToEndContextGovernanceClosure::QuintTraceScalarReplayContract("
            f"{rec['slice_id']},{rec['steps']},{b(rec['consumed'])},"
            f"{b(rec['cut_ok'])},{b(rec['grant_ok'])},{b(rec['epist_ok'])})"
        )
        replay_cases.append((rec, subj))
        cmd += ["-analysis", subj]

    rres = subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=False)
    (out_dir / "sysml-itf-trace-replay.json").write_text(rres.stdout, encoding="utf-8")
    rpayload = json.loads(rres.stdout)
    rchecks = rpayload.get("checks") or []
    if rpayload.get("errors") or len(rchecks) != len(replay_cases):
        raise RuntimeError(f"SysML ITF trace replay JSON error: {rres.stderr}")

    replayed_summary = []
    for (rec, subj), chk in zip(replay_cases, rchecks):
        expect_fail = rec["expect_unsafe"]
        expected_status = "fails" if expect_fail else "holds"
        expected_kind = "fail" if expect_fail else "pass"
        verdicts = chk.get("verifications") or []
        values = {row["name"]: row["value"] for row in chk.get("values", [])}
        if (
            chk.get("subject") != subj
            or chk.get("status") != expected_status
            or len(verdicts) != 1
            or verdicts[0].get("kind") != expected_kind
            or values.get("replayedSlice") != str(rec["slice_id"])
            or values.get("observedSteps") != str(rec["steps"])
        ):
            raise RuntimeError(
                f"SysML<->Quint ITF scalar replay mismatch on {rec['slice']}::{rec['test']}: {chk}"
            )
        replayed_summary.append(
            {
                "slice": rec["slice"],
                "test": rec["test"],
                "steps": rec["steps"],
                "trace_sha256": rec["trace_sha256"],
                "expected_unsafe": expect_fail,
                "sysml_verdict": verdicts[0]["kind"],
            }
        )

    return {
        "sysml_dispatch_runs": len(dispatch_executed),
        "sysml_itf_replay_runs": len(replayed_summary),
        "replayed_traces": replayed_summary,
    }


def verify_render_receipts() -> dict:
    out_dir = ROOT / "dev/d2/output"
    checked = []
    for slug in STORY_SLUGS:
        rfile = out_dir / f"{slug}.receipt.json"
        if not rfile.exists():
            raise RuntimeError(f"Missing OpenSysML render receipt: {rfile}")
        data = json.loads(rfile.read_text(encoding="utf-8"))
        readability = data["rendering"]["readability"]
        if readability["minimumTextSize"] < readability["requiredMinimum"]:
            raise RuntimeError(f"Readability gate violated in {slug}: {readability}")
        checked.append(
            {
                "story": slug,
                "minimumTextSize": readability["minimumTextSize"],
                "sourceSHA256": data["sourceSHA256"],
            }
        )
    return {"verified_figures": checked}


def verify_lake_workspace(out_dir: Path) -> dict:
    build_res = subprocess.run(
        ["lake", "build"],
        cwd=str(LAKE_DIR),
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    (out_dir / "lake-build.log").write_text(build_res.stdout + build_res.stderr, encoding="utf-8")
    if build_res.returncode != 0:
        raise RuntimeError(f"Lake build failed in {LAKE_DIR}:\n{build_res.stdout}\n{build_res.stderr}")

    audit_res = subprocess.run(
        ["lake", "env", "lean", "ContextGovernanceAxioms.lean"],
        cwd=str(LAKE_DIR),
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    audit_out = audit_res.stdout + audit_res.stderr
    (out_dir / "lake-axiom-audit.log").write_text(audit_out, encoding="utf-8")
    if audit_res.returncode != 0:
        raise RuntimeError(f"Lake full-namespace axiom audit failed:\n{audit_out}")
    m = re.search(
        r"CONTEXT-GOVERNANCE-LAKE-AXIOM-AUDIT-OK:\s*(\d+)\s+declarations across\s+(\d+)\s+namespaces",
        audit_out,
    )
    if not m:
        raise RuntimeError(f"Unexpected Lake axiom audit output:\n{audit_out}")
    return {
        "lake_dir": str(LAKE_DIR.relative_to(ROOT)),
        "lean_toolchain": (LAKE_DIR / "lean-toolchain").read_text(encoding="utf-8").strip(),
        "audited_declarations": int(m.group(1)),
        "audited_namespaces": int(m.group(2)),
    }


def compute_source_bindings(
    lean_bindings: list[dict] | None = None,
    quint_bindings: list[dict] | None = None,
) -> dict:
    lean_by_slice: dict[str, set[str]] = {}
    if lean_bindings is not None:
        for item in lean_bindings:
            lean_by_slice.setdefault(item["slice"], set()).update(item["theorems"])

    quint_by_slice: dict[str, set[str]] = {}
    if quint_bindings is not None:
        for item in quint_bindings:
            quint_by_slice.setdefault(item["slice"], set()).update(item["invariants"])

    supporting_files = {}
    for rel in SUPPORTING_BINDING_PATHS:
        target = ROOT / rel
        if not target.exists():
            raise RuntimeError(f"Missing supporting file for source-binding ledger: {rel}")
        supporting_files[rel] = sha256_hex(target)

    slice_bindings = {}
    for slice_id, stem, *_ in SLICES:
        tuple_digests = {
            ext: sha256_hex(HERE / f"{stem}.{ext}") for ext in ("org", "sysml", "lean", "qnt")
        }
        bundle_hash = hashlib.sha256(
            json.dumps(tuple_digests, sort_keys=True).encode("utf-8")
        ).hexdigest()
        entry: dict = {
            "slice_id": slice_id,
            "bundle_sha256": bundle_hash,
            "files": tuple_digests,
        }
        if lean_bindings is not None:
            entry["lean_theorems"] = sorted(lean_by_slice.get(stem, set()))
        if quint_bindings is not None:
            entry["quint_invariants"] = sorted(quint_by_slice.get(stem, set()))
        slice_bindings[stem] = entry

    aggregate_payload = {
        "supporting_files": supporting_files,
        "slices": {k: v["bundle_sha256"] for k, v in slice_bindings.items()},
    }
    aggregate_hash = hashlib.sha256(
        json.dumps(aggregate_payload, sort_keys=True).encode("utf-8")
    ).hexdigest()

    return {
        "schema": "agentic-ai-context-governance-source-bindings-v1",
        "toolchain": {
            "lean_toolchain": (LAKE_DIR / "lean-toolchain").read_text(encoding="utf-8").strip(),
            "opensysml_version": PINNED_OPENSYSML_VERSION,
            "quint_apalache_version": PINNED_APALACHE_VERSION,
        },
        "aggregate_bundle_sha256": aggregate_hash,
        "supporting_files": supporting_files,
        "slices": slice_bindings,
    }


def verify_source_bindings(
    bindings_path: Path,
    actual: dict,
    *,
    check_inventories: bool,
) -> dict:
    if not bindings_path.exists():
        raise RuntimeError(
            f"Missing pinned source-binding lockfile: {bindings_path} "
            f"(generate after full verification with --write-bindings)"
        )
    expected = json.loads(bindings_path.read_text(encoding="utf-8"))
    drifts: list[str] = []

    if expected.get("schema") != actual["schema"]:
        drifts.append(f"schema: expected={expected.get('schema')} actual={actual['schema']}")
    if expected.get("toolchain") != actual["toolchain"]:
        drifts.append(f"toolchain: expected={expected.get('toolchain')} actual={actual['toolchain']}")

    exp_sup = expected.get("supporting_files", {})
    act_sup = actual["supporting_files"]
    for rel in sorted(set(exp_sup) | set(act_sup)):
        if exp_sup.get(rel) != act_sup.get(rel):
            drifts.append(f"supporting:{rel} expected={exp_sup.get(rel)} actual={act_sup.get(rel)}")

    exp_slices = expected.get("slices", {})
    act_slices = actual["slices"]
    for stem in sorted(set(exp_slices) | set(act_slices)):
        es = exp_slices.get(stem)
        ac = act_slices.get(stem)
        if es is None or ac is None:
            drifts.append(f"slice:{stem} presence mismatch")
            continue
        for ext in ("org", "sysml", "lean", "qnt"):
            ev = (es.get("files") or {}).get(ext)
            av = (ac.get("files") or {}).get(ext)
            if ev != av:
                drifts.append(f"slice:{stem}.{ext} expected={ev} actual={av}")
        if es.get("bundle_sha256") != ac.get("bundle_sha256"):
            drifts.append(f"slice:{stem}:bundle_sha256 expected={es.get('bundle_sha256')} actual={ac.get('bundle_sha256')}")
        if check_inventories:
            if es.get("lean_theorems") != ac.get("lean_theorems"):
                drifts.append(f"slice:{stem}:lean_theorems mismatch")
            if es.get("quint_invariants") != ac.get("quint_invariants"):
                drifts.append(f"slice:{stem}:quint_invariants mismatch")

    if expected.get("aggregate_bundle_sha256") != actual["aggregate_bundle_sha256"]:
        drifts.append(
            f"aggregate_bundle_sha256 expected={expected.get('aggregate_bundle_sha256')} "
            f"actual={actual['aggregate_bundle_sha256']}"
        )

    if drifts:
        detail = "\n  - ".join(drifts)
        raise RuntimeError(
            f"Source-binding lockfile drift detected against {bindings_path.name}:\n  - {detail}"
        )

    return {
        "verified": True,
        "bindings_file": str(bindings_path.relative_to(ROOT)) if bindings_path.is_relative_to(ROOT) else str(bindings_path),
        "aggregate_bundle_sha256": actual["aggregate_bundle_sha256"],
        "supporting_files_checked": len(act_sup),
        "slices_checked": len(act_slices),
        "inventories_checked": check_inventories,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, default=None, help="Output directory for verification logs & summary")
    parser.add_argument("--max-steps", type=int, default=8, help="Apalache bounded step horizon for composed 47.qnt")
    parser.add_argument("--check-renders", action="store_true", help="Verify OpenSysML render receipts in dev/d2/output")
    parser.add_argument("--check-lake", action="store_true", help="Run proofs/ContextGovernance lake build + full-namespace axiom audit")
    parser.add_argument("--bindings", type=Path, default=DEFAULT_BINDINGS_PATH, help="Path to pinned SHA-256 source-binding lockfile")
    parser.add_argument("--verify-bindings", action="store_true", help="Fail closed if any source hash or SysML binding drifts from the lockfile")
    parser.add_argument("--bindings-only", action="store_true", help="Run only the static SHA-256 source-binding drift check against the lockfile")
    parser.add_argument("--write-bindings", action="store_true", help="Write/refresh the pinned SHA-256 source-binding lockfile after full verification succeeds")
    args = parser.parse_args()

    if args.write_bindings and (args.verify_bindings or args.bindings_only):
        raise SystemExit("--write-bindings cannot be combined with --verify-bindings or --bindings-only")

    if args.bindings_only:
        actual = compute_source_bindings()
        report = verify_source_bindings(args.bindings.resolve(), actual, check_inventories=False)
        print(
            f"CONTEXT-GOVERNANCE-BINDINGS-OK "
            f"slices={report['slices_checked']} "
            f"supporting={report['supporting_files_checked']} "
            f"aggregate_sha256={report['aggregate_bundle_sha256']}",
            flush=True,
        )
        return

    temp_ctx = tempfile.TemporaryDirectory(prefix="ctx-gov-chain-") if args.artifacts is None else None
    try:
        out_dir = Path(temp_ctx.name) if temp_ctx is not None else args.artifacts.resolve()
        out_dir.mkdir(parents=True, exist_ok=True)

        print("CHAIN-STAGE-1 [ORG -> SysML v2 Taxonomy & Bidirectional XOR Dispatch]", flush=True)
        org_info = verify_org_and_links()
        sysml_info = parse_and_audit_sysml_taxonomy(out_dir)

        print("CHAIN-STAGE-2 [SysML v2 -> Lean 4 Imported DAG (40..46,48->47) & Kernel AxiomAudit]", flush=True)
        lake_info = verify_lake_workspace(out_dir) if args.check_lake else None
        lean_info = verify_lean_dag_and_axioms(out_dir, sysml_info["lean_bindings"])

        print("CHAIN-STAGE-3 [SysML v2 -> Quint 100% Bidirectional Invariants, Exhaustive TLC (8) + Apalache (47) & ITF Export]", flush=True)
        quint_info, itf_records = verify_quint_tlc_apalache_and_export_itf(
            out_dir, sysml_info["quint_bindings"], args.max_steps
        )

        print("CHAIN-STAGE-4 [Computed Verdicts + Real Quint ITF Traces -> SysML v2 -engine run -json Closure]", flush=True)
        run_info = replay_verdicts_and_itf_traces_into_sysml(
            out_dir,
            lean_ok=lean_info["verified_theorems_count"] > 0,
            quint_ok=len(quint_info["verified_models"]) == len(SLICES),
            xor_ok=sysml_info["xor_disjoint"],
            itf_records=itf_records,
        )

        render_info = verify_render_receipts() if args.check_renders else {"verified_figures": []}

        bindings_ledger = compute_source_bindings(
            lean_bindings=sysml_info["lean_bindings"],
            quint_bindings=sysml_info["quint_bindings"],
        )
        bindings_verification = None
        if args.verify_bindings:
            bindings_verification = verify_source_bindings(
                args.bindings.resolve(),
                bindings_ledger,
                check_inventories=True,
            )
        elif args.write_bindings:
            target_bindings = args.bindings.resolve()
            target_bindings.write_text(json.dumps(bindings_ledger, indent=2) + "\n", encoding="utf-8")
            bindings_verification = {
                "written": True,
                "bindings_file": str(target_bindings.relative_to(ROOT)) if target_bindings.is_relative_to(ROOT) else str(target_bindings),
                "aggregate_bundle_sha256": bindings_ledger["aggregate_bundle_sha256"],
            }

        summary = {
            "schema": "agentic-ai-context-governance-chain-v2",
            "org": org_info,
            "sysml_taxonomy": {
                "elements": sysml_info["elements"],
                "checks": sysml_info["checks"],
                "classified_requirements": sysml_info["total_classified_requirements"],
                "xor_disjoint": sysml_info["xor_disjoint"],
                "bidirectional_quint_safety_coverage": "100%",
            },
            "lean_dag": {
                "compiled_modules": lean_info["compiled_modules"],
                "verified_theorems": lean_info["verified_theorems_count"],
                "axiom_audit": lean_info["axiom_audit"],
                "lake_workspace": lake_info,
            },
            "quint_verification": quint_info,
            "sysml_closure": run_info,
            "renders": render_info,
            "source_binding_ledger": bindings_ledger,
            "source_binding_verification": bindings_verification,
        }
        (out_dir / "context-governance-chain-summary.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8"
        )
        shutil.rmtree(ROOT / "_apalache-out", ignore_errors=True)
        tlc_models = [m for m in quint_info["verified_models"] if m["backend"] == "tlc"]
        tlc_total_distinct = sum(m["distinct_states"] for m in tlc_models)
        lake_suffix = (
            f" lake_audited_decls={lake_info['audited_declarations']}" if lake_info is not None else ""
        )
        bind_suffix = (
            f" bindings_sha256={bindings_ledger['aggregate_bundle_sha256'][:12]}"
            if bindings_verification is not None
            else ""
        )
        print(
            f"CONTEXT-GOVERNANCE-CHAIN-OK "
            f"sysml_checks={sysml_info['checks']} "
            f"lean_theorems={lean_info['verified_theorems_count']}{lake_suffix} "
            f"tlc_exhaustive_models={len(tlc_models)}(distinct={tlc_total_distinct},queue=0) "
            f"composed_apalache=1 "
            f"sysml_dispatch_runs={run_info['sysml_dispatch_runs']} "
            f"sysml_itf_replays={run_info['sysml_itf_replay_runs']}{bind_suffix}",
            flush=True,
        )
    finally:
        if temp_ctx is not None:
            temp_ctx.cleanup()


if __name__ == "__main__":
    main()
