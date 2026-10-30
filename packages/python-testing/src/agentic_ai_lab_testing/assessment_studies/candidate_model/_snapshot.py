# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the candidate model study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from pathlib import Path
import subprocess
from ._artifacts import digest, save
from ._config import CANONICAL, PREPARED, ROOT, RUNTIME, TOOL
from ._tasks import request, task
from ._transport import Consumer


def freeze(run):
    run.mkdir(parents=True, exist_ok=False)
    native = Consumer(run)
    try:
        groups = []
        try:
            for i in range(8):
                groups.append(native.call(op="qualify", group=i))
            if [g.get("checks") for g in groups] != [64] * 7 + [0]:
                raise ValueError("native qualification group failed")
            qualification = {
                "checks": sum(g["checks"] for g in groups),
                "staleRejected": groups[7].get("staleRejected"),
                "boundedNotMatch": groups[7].get("boundedNotMatch"),
            }
            if qualification != {
                "checks": 448,
                "staleRejected": True,
                "boundedNotMatch": True,
            }:
                raise ValueError(
                    "native qualification failed: " + json.dumps(qualification)
                )
            qualified = True
        except ValueError as error:
            qualified = False
            qualification = {
                "admitted": False,
                "error": str(error),
                "completedGroups": groups,
            }
            save(
                run / "correct-control.json",
                native.call(
                    op="feedback",
                    case=0,
                    rules=[
                        [["path", "?x", "?y"], ["edge", "?x", "?y"]],
                        [
                            ["path", "?x", "?z"],
                            ["path", "?x", "?y"],
                            ["edge", "?y", "?z"],
                        ],
                    ],
                ),
            )
        tasks = [
            task(i, native.call(op="feedback", case=i, rules=[])) for i in range(3)
        ]
    finally:
        native.close()
    save(run / "qualification.json", qualification)
    paths = [
        _study_module_file("candidate_model"),
        ROOT / "t/research/candidate-interaction.ss",
        _study_module_file("model_study"),
        _study_module_file("movie_study"),
        ROOT / "t/model/source-closure.ss",
    ]
    modules = json.loads((RUNTIME / "closure.json").read_text())["modules"]
    if any("agentic-ai-lab" in m for m in modules):
        raise ValueError("workflow dependency in Library fixture")
    # Resolve only the compiler-reported runtime closure, not unrelated prepared modules.
    system = Path(
        subprocess.check_output(
            [
                "/opt/homebrew/bin/gxi",
                "-e",
                '(display (path-expand "lib" (gerbil-home)))',
            ],
            text=True,
        ).strip()
    )
    for module in modules:
        rel = module.lstrip(":").split("~", 1)[0]
        found = False
        for lib in [CANONICAL, RUNTIME / "lib", PREPARED, system]:
            prefix = lib / rel
            files = [
                p
                for p in prefix.parent.glob(prefix.name + "*")
                if p.is_file() and not p.name.endswith(".lock")
            ]
            if files:
                paths += files
                found = True
                break
        if not found:
            raise ValueError("unbound runtime module " + module)
        src = ROOT / (rel.removeprefix("gerbil-ascent/") + ".ss")
        captured = RUNTIME / "current-source" / src.relative_to(ROOT)
        if "t/research/" not in str(src) and captured.exists():
            src = captured
        if src.exists():
            paths.append(src)
            relative = (
                src.relative_to(RUNTIME / "current-source")
                if src.is_relative_to(RUNTIME / "current-source")
                else src.relative_to(ROOT)
            )
            old = ROOT / ".cache/ascent/crosspath-search/snapshot" / relative
            if (
                "t/research/" not in str(src)
                and old.exists()
                and src.read_bytes() != old.read_bytes()
            ):
                receipt_path = RUNTIME / "current-source-build.json"
                receipts = (
                    json.loads(receipt_path.read_text())
                    if receipt_path.exists()
                    else {}
                )
                rebuilt = receipts.get(str(relative), {})
                if rebuilt.get("sourceSha256") != digest(src) or not rebuilt.get(
                    "compiledC"
                ):
                    raise ValueError("prepared source drift " + str(src))
                if rebuilt.get("compiledCSha256") != digest(Path(rebuilt["compiledC"])):
                    raise ValueError("rebuilt module artifact drift " + str(src))
                if rebuilt["compiledC"] not in json.loads(
                    (RUNTIME / "native-object-sources.json").read_text()
                ):
                    raise ValueError(
                        "rebuilt source absent from native link " + str(src)
                    )
                paths.append(receipt_path)
    paths += [RUNTIME / "bin/candidate-interaction", RUNTIME / "closure.json"]
    native_sources = [
        Path(p)
        for p in json.loads((RUNTIME / "native-object-sources.json").read_text())
    ]
    for module in modules:
        name = module.replace("/", "__") + ".c"
        for static in (
            CANONICAL / "static",
            RUNTIME / "lib/static",
            PREPARED / "static",
            system / "static",
        ):
            if (static / name).exists() and name not in {
                p.name for p in native_sources
            }:
                raise ValueError(
                    "runtime submodule omitted from native link: " + module
                )
    paths += native_sources
    paths += list((RUNTIME / "native-objects").glob("*.o"))
    capture = RUNTIME / "source-capture.json"
    if capture.exists():
        for relative, sha in json.loads(capture.read_text())["sourceSha256"].items():
            captured = RUNTIME / "current-source" / relative
            if digest(captured) != sha:
                raise ValueError("captured source drift " + relative)
            paths.append(captured)
        paths.append(capture)
    binding = _source_hashes({str(p): p for p in sorted(set(paths))})
    plan = {
        "tasks": tasks,
        "tool": TOOL,
        "binding": binding,
        "model": "deepseek-flash",
        "budgetPerTrajectory": 32768,
        "nativeQualified": qualified,
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "librarySourceCapture": json.loads(capture.read_text())
        if capture.exists()
        else None,
        "qualificationSha256": digest(run / "qualification.json"),
        "outputCap": 8192,
        "developmentMasks": [0, 1, 3, 9],
        "heldOutMasks": [i for i in range(64) if i not in (0, 1, 3, 9)],
        "protocol": "One initial model proposal per task. Only a completed, known-cost proposal failing visible development rows receives one paired revision: same proposal/task, baseline without feedback versus native complete-row feedback. Hidden masks never drive repair. Charge shared initial cost to both trajectories; physical calls count once. No retries, anti-repetition instructions or search controller.",
        "limits": "Finite three-node synthesis/feedback integration gate, not corpus reproduction or proof of reduced thinking. If every development proposal passes, assistance comparison is unexercised. No new formal proof or current-head remote CI claim.",
    }
    save(run / "plan.json", plan)
    (run / "plan.sha256").write_text(digest(run / "plan.json") + "\n")
    for path in paths:
        if path.suffix == ".py" or path == ROOT / "t/research/candidate-interaction.ss":
            dest = run / "producers" / path.relative_to(ROOT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(path.read_bytes())
    save(
        run / "payload-review.json",
        {
            "destination": "https://api.deepseek.com/responses",
            "payload": "Synthetic Datalog specifications, four visible graphs and candidate rules. No source files, private records or credentials.",
            "requests": [request(t) for t in tasks],
        },
    )
    report_text(
        "FROZEN" if qualified else "FROZEN_NOT_ADMITTED",
        qualification,
        digest(run / "plan.json"),
        flush=True,
    )


def verify(run, plan):
    if digest(run / "plan.json") != (run / "plan.sha256").read_text().strip():
        raise ValueError("plan drift")
    if digest(run / "qualification.json") != plan["qualificationSha256"]:
        raise ValueError("qualification drift")
    for p, h in plan["binding"].items():
        if digest(Path(p)) != h:
            raise ValueError("producer drift " + p)
