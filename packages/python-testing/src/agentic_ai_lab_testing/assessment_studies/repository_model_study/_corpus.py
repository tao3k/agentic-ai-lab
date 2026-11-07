# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Corpus for the repository model study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_label

from agentic_ai_lab_testing.assessment_studies._source_files import (
    _source_hashes,
    _source_files,
)

from agentic_ai_lab_testing.model_study.reporting import report_text
import ast
import copy
import hashlib
import json
from pathlib import Path
import shutil
from agentic_ai_lab_runtime.reasoning import identity
from ..repository_corpus import tree_identity, test_receipt, qualify, provenance
from ._config import ARMS, CASES, CORPUS, ROOT


def copy_snapshot(source, destination):
    # GitHub archive links and generated files are not model-visible inputs.
    ignored = shutil.ignore_patterns(
        "__pycache__", ".pytest_cache", ".git", ".hypothesis"
    )
    shutil.copytree(source, destination, ignore=ignored, symlinks=True)
    for path in destination.rglob("*"):
        if path.is_symlink():
            path.unlink()


def _qualify_corpus_tasks(directory, audit):
    """Own the qualify corpus tasks phase without weakening its checks."""
    tasks = []
    for case in CASES:
        case = copy.deepcopy(case)
        record = json.loads(
            (CORPUS / "discovery-20261010" / (case["metadata"] + ".json")).read_text()
        )
        admitted = provenance(
            record,
            earliest=audit["earliestDisclosure"],
            frozen_at=audit["provenanceCutoff"],
        )
        if not admitted["eligible"]:
            raise ValueError("task provenance failed")
        receipts = [
            test_receipt(
                CORPUS / case["name"] / (label + ".xml"),
                json.loads(
                    (CORPUS / case["name"] / (label + ".exit.json")).read_text()
                )["exitCode"],
            )
            for label in ("before", "after")
        ]
        if not qualify(*receipts)["qualified"]:
            raise ValueError("task execution qualification failed")
        case["expectedTestNames"] = sorted(name for _, name in receipts[1]["cases"])
        destination = directory / case["name"]
        destination.mkdir()
        copy_snapshot(CORPUS / case["name"] / "parent", destination / "parent")
        case["snapshotIdentity"], case["files"] = tree_identity(destination / "parent")
        shutil.copy2(
            CORPUS / case["name"] / "fixed" / case["testFile"],
            destination / "grading.py",
        )
        case["graderSha256"] = hashlib.sha256(
            (destination / "grading.py").read_bytes()
        ).hexdigest()
        case["provenance"] = admitted
        tasks.append(case)
    return tasks


def _snapshot_producers(sources, destination):
    """Freeze every hashed input, including separately installed source owners."""
    for path in sources.values():
        # Absolute source identities remain truthful in producerHashes. Their
        # copied bytes must nevertheless stay inside this run's evidence tree.
        relative = (
            path.relative_to(ROOT)
            if path.is_relative_to(ROOT)
            else Path("external") / Path(*path.parts[1:])
        )
        snapshot = destination / relative
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, snapshot)


def prepare(directory):
    directory.mkdir(parents=True, exist_ok=False)
    audit = json.loads((CORPUS / "fresh-source-audit.json").read_text())
    tasks = _qualify_corpus_tasks(directory, audit)
    library = ROOT / ".gerbil/lib/libascent.dylib"
    shutil.copy2(library, directory / "libascent.dylib")
    paths = [
        Path(__file__),
        (Path(__file__).parent.parent / "model_study/__init__.py"),
        (Path(__file__).parent.parent / "movie_study/__init__.py"),
        (Path(__file__).parent.parent / "inference_effort.py"),
        (Path(__file__).parent.parent / "inference_reuse_study/__init__.py"),
        (Path(__file__).parent.parent / "repository_corpus.py"),
        (Path(__file__).parent.parent / "evidence_chain_study/__init__.py"),
        ROOT / "rust/ascent/src/derivations.rs",
        ROOT / "rust/ascent-python/src/api/evidence.rs",
        ROOT / "rust/ascent/src/conversation.rs",
        ROOT / "rust/ascent-python/src/api/exports.rs",
    ]
    sources = _source_files({_source_label(p, ROOT): p for p in paths})
    hashes = _source_hashes(sources)
    _snapshot_producers(sources, directory / "producer-snapshot")
    plan = {
        "schema": "ascent.repository-model-study.v1",
        "tasks": tasks,
        "arms": list(ARMS),
        "repetitions": 2,
        "maxTurns": 10,
        "maxOutputTokens": 131072,
        "workers": 2,
        "producerHashes": hashes,
        "verifyCandidatesOnEdit": True,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "dependencies": audit["dependencies"],
        "scope": "Two independently sourced repair tasks; pilot, not four-family coverage or proof of unseen training.",
    }
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    report_text(
        "REPOSITORY-PLAN-FROZEN",
        len(tasks),
        "tasks",
        len(tasks) * 2 * 3,
        "trajectories",
        flush=True,
    )


def symbol_table(directory, files):
    entries = {}
    edges = set()
    for relative in files:
        parsed = ast.parse((directory / relative).read_text())
        definitions = [
            node
            for node in parsed.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        ]
        local = {
            node.name: "s"
            + hashlib.sha256((relative + ":" + node.name).encode()).hexdigest()[:20]
            for node in definitions
        }
        for node in definitions:
            token = local[node.name]
            entries[token] = {
                "name": node.name,
                "file": relative,
                "start": node.lineno,
                "end": node.end_lineno,
            }
            for call in ast.walk(node):
                if (
                    isinstance(call, ast.Call)
                    and isinstance(call.func, ast.Name)
                    and call.func.id in local
                ):
                    edges.add((token, local[call.func.id]))
    return entries, sorted(edges)


def evidence_program(entries, edges, roots, snapshot=None):
    domain = sorted(entries)
    column = {"kind": "symbol", "domain": domain}
    relations = [
        {
            "name": "Defined",
            "columns": [column],
            "source": True,
            "rows": [[x] for x in domain],
        },
        {
            "name": "SyntacticReference",
            "columns": [column, column],
            "source": True,
            "rows": [list(e) for e in edges],
        },
        {"name": "reachable", "columns": [column, column], "source": False, "rows": []},
        {"name": "support", "columns": [column], "source": False, "rows": []},
    ]
    snapshot = snapshot or identity({"entries": entries, "edges": edges})
    relations.append(
        {
            "name": "Snapshot",
            "columns": [{"kind": "symbol", "domain": [snapshot]}],
            "source": True,
            "rows": [[snapshot]],
        }
    )

    def var(n):
        return {"var": n}

    def atom(n, *terms):
        return {"relation": n, "terms": list(terms)}

    rules = [
        {
            "head": [atom("reachable", var("x"), var("y"))],
            "body": [atom("SyntacticReference", var("x"), var("y"))],
        },
        {
            "head": [atom("reachable", var("x"), var("z"))],
            "body": [
                atom("reachable", var("x"), var("y")),
                atom("SyntacticReference", var("y"), var("z")),
            ],
        },
    ]
    for root in roots:
        rules.extend(
            [
                {
                    "head": [atom("support", var("x"))],
                    "body": [
                        atom("Defined", var("x")),
                        atom("reachable", {"const": root}, var("x")),
                    ],
                },
                {
                    "head": [atom("support", {"const": root})],
                    "body": [atom("Defined", {"const": root})],
                },
            ]
        )
    return {"relations": relations, "rules": rules, "queries": ["support"]}


def grading_scope(text, targets):
    """Preserve selected upstream definitions; exclude unrelated suite imports."""
    parsed = ast.parse(text)
    names = {target.split("::")[1] for target in targets}
    imports = [n for n in parsed.body if isinstance(n, (ast.Import, ast.ImportFrom))]
    future = [
        n for n in imports if isinstance(n, ast.ImportFrom) and n.module == "__future__"
    ]
    imports = [n for n in imports if n not in future]
    selected = [
        n
        for n in parsed.body
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and n.name in names
    ]
    if {n.name for n in selected} != names:
        raise ValueError("qualification test scope missing")
    # Preserve referenced base classes, helpers and global symbol declarations.
    # The extracted file remains grader-only; this does not expose hidden tests.
    while True:
        references = {
            n.id
            for node in selected
            for n in ast.walk(node)
            if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)
        }
        extra = []
        for node in parsed.body:
            if node in selected:
                continue
            defined = (
                {node.name}
                if isinstance(node, (ast.FunctionDef, ast.ClassDef))
                else (
                    {
                        n.id
                        for target in node.targets
                        for n in ast.walk(target)
                        if isinstance(n, ast.Name)
                    }
                    if isinstance(node, ast.Assign)
                    else set()
                )
            )
            if defined & references:
                extra.append(node)
        if not extra:
            break
        selected.extend(extra)
    selected = [node for node in parsed.body if node in selected]
    # Real import lifecycle output, not timer heartbeats.
    code = [ast.get_source_segment(text, n) for n in future]
    for node in imports:
        code.append(
            'print("TEST-SCOPE-IMPORT '
            + str(getattr(node, "module", None) or node.names[0].name)
            + '",flush=True)'
        )
        code.append(ast.get_source_segment(text, node))
    code.extend(ast.get_source_segment(text, n) for n in selected)
    return "\n\n".join(code) + "\n"
