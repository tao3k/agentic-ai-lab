# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workspace for the repository model study study."""

import ast
import copy
import hashlib
import json
import os
import shutil
import subprocess
import time
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import DomainEvidence
from agentic_ai_lab_runtime.reasoning import identity
from ..repository_corpus import test_receipt
from ._config import CORPUS, ENGINE
from ._corpus import copy_snapshot, evidence_program, grading_scope, symbol_table
from ._runner import observed_runner


def _prepare_execution_sandbox(self, run, logpath):
    """Own the prepare execution sandbox phase and retain its evidence checks."""
    env = {k: v for k, v in os.environ.items() if k in ("PATH", "LANG", "LC_ALL")}
    env.update(
        PYTHONPATH=str(self.root),
        PYTEST_DISABLE_PLUGIN_AUTOLOAD="1",
        PYTHONDONTWRITEBYTECODE="1",
        HOME=str(run),
        TMPDIR=str(run),
    )
    # The child can read its workspace and dependency runtime, not .env or
    # fixed sources. It may write only this execution's temporary directory.
    allowed = [
        str(self.root),
        str(CORPUS / "environment"),
        "/nix/store",
        "/System",
        "/usr",
        "/Library",
        "/opt/homebrew",
        "/private/var/db",
        "/dev",
        "/etc",
        "/private/etc",
        "/bin",
        "/sbin",
    ]
    read_paths = [str(self.root), str(CORPUS / "execution-environment"), str(run)]
    # Platform loaders need their normal system reads. Deny user-directory
    # contents outside the three explicitly exposed evaluator directories.
    deny_reads = (
        '(require-all (require-any (subpath "/Users") (subpath "/System/Volumes/Data/Users")) '
        + " ".join("(require-not (subpath " + json.dumps(p) + "))" for p in read_paths)
        + ")"
    )
    deny_writes = (
        "(require-all (require-not (subpath "
        + json.dumps(str(run))
        + ")) (require-not (literal "
        + json.dumps(str(logpath))
        + ')) (require-not (subpath "/dev")))'
    )
    # Preserve platform process/loader operations while restricting contents,
    # writes and networking. A deny-default profile broke Nix's launcher.
    profile = (
        "(version 1)(allow default)(deny network*)(deny file-read-data "
        + deny_reads
        + ")(deny file-write* "
        + deny_writes
        + ")"
    )
    sandbox = run / "sandbox.sb"
    sandbox.write_text(profile)
    return env, sandbox


def _run_bounded_execution(self, logpath, sandbox, command, env):
    """Own the run bounded execution phase and retain its evidence checks."""
    began = time.monotonic()
    with logpath.open("w") as log:
        child = subprocess.Popen(
            ["/usr/bin/sandbox-exec", "-f", str(sandbox), *command],
            cwd=self.root,
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        last = began
        size = 0
        while child.poll() is None:
            time.sleep(0.1)
            now = logpath.stat().st_size
            if now != size:
                size = now
                last = time.monotonic()
            if time.monotonic() - last > 5:
                child.kill()
                child.wait()
                raise TimeoutError(
                    "test execution made no actual log progress for five seconds"
                )
        status = child.returncode
    return status, began


def _qualify_execution_receipt(self, xml, status, visible, began, grading):
    """Own the qualify execution receipt phase and retain its evidence checks."""
    if not xml.exists():
        raise RuntimeError(
            "test environment did not produce a complete receipt; exit=" + str(status)
        )
    receipt = test_receipt(xml, status)
    counts = {
        state: sum(x == state for x in receipt["cases"].values())
        for state in ("passed", "failed", "skipped", "error")
    }
    expected = (
        len(self.case["expectedTestNames"])
        if "expectedTestNames" in self.case
        else len(receipt["cases"])
    )
    names = sorted(name for _, name in receipt["cases"])
    verified = (
        grading
        and status == 0
        and len(receipt["cases"]) == expected
        and counts["passed"] == expected
        and names == self.case.get("expectedTestNames", names)
    )
    result = {
        "verified": verified,
        "allChecksPassed": status == 0
        and counts["passed"] == len(receipt["cases"])
        and bool(receipt["cases"]),
        "exitCode": status,
        "counts": counts,
        "sourceIdentity": self.source_identity,
        "seconds": time.monotonic() - began,
        "kind": "hidden-grading" if grading else "development-tests",
    }
    if not grading:
        result["observedOutput"] = visible[-12000:]
    return result


class Workspace:
    def __init__(self, plan_dir, directory, case, arm):
        global ENGINE
        plan_dir = plan_dir.resolve()
        directory = directory.resolve()
        self.root = directory / "workspace"
        copy_snapshot(plan_dir / case["name"] / "parent", self.root)
        self.directory = directory
        self.case = case
        self.arm = arm
        self.chain = None
        self.journal = []
        self.generation = 0
        self.domain = None
        self.sealed_candidate = None
        self.regenerate()
        if arm != "ordinary-tools":
            if ENGINE is None:
                ENGINE = ReasoningRuntime(plan_dir / "libascent.dylib")
            self.regenerate()
        self.grader = plan_dir / case["name"] / "grading.py"

    def regenerate(self):
        if self.chain:
            self.chain.close()
            self.chain = None
        self.entries, self.edges = symbol_table(self.root, self.case["editable"])
        self.source_identity = identity(
            {
                p: hashlib.sha256((self.root / p).read_bytes()).hexdigest()
                for p in self.case["editable"]
            }
        )
        if self.arm != "ordinary-tools" and ENGINE:
            program = evidence_program(
                self.entries, self.edges, [], self.source_identity
            )
            self.chain = EvidenceChain(
                ENGINE,
                [r for r in program["relations"] if r["source"]],
                self.arm == "scheme-retained",
            )
            if self.case.get("domainKind"):
                if getattr(self, "domain", None):
                    self.domain.replace_snapshot(self.source_identity)
                else:
                    self.domain = DomainEvidence(
                        ENGINE, self.source_identity, self.arm == "scheme-retained"
                    )

    def read(self, path, start=1, end=None):
        if (
            path not in self.case["files"]
            or not path.startswith(self.case["package"] + "/")
            or not path.endswith(".py")
        ):
            raise ValueError(
                "read only parent package source files; history and hidden grading artifacts are not exposed"
            )
        lines = (self.root / path).read_text().splitlines()
        start = int(start)
        end = min(int(end or start + 159), start + 199, len(lines))
        if start < 1:
            raise ValueError("line numbers begin at 1")
        result = {
            "path": path,
            "start": start,
            "end": end,
            "totalLines": len(lines),
            "sourceIdentity": self.source_identity,
            "text": "\n".join(
                f"{i + 1}: {line}"
                for i, line in enumerate(lines[start - 1 : end], start - 1)
            ),
        }
        if self.chain:
            roots = [
                token
                for token, e in self.entries.items()
                if e["file"] == path and e["start"] <= end and e["end"] >= start
            ]
            if roots:
                roots = roots[:16]
                began = time.monotonic()
                receipt = self.chain.query(
                    evidence_program(
                        self.entries, self.edges, roots, self.source_identity
                    )
                )
                self.journal.append(
                    {
                        "generation": self.generation,
                        "sourceIdentity": self.source_identity,
                        "seconds": time.monotonic() - began,
                        "reusedComponents": receipt["reusedComponents"],
                        "freshComponents": receipt["freshComponents"],
                        "pathIdentity": receipt["pathIdentity"],
                    }
                )
                # Matched Scheme arms expose identical checked facts, not cache hints.
                result["checkedSyntacticSupport"] = [
                    self.entries[row[0]]
                    for row in sorted(receipt["result"]["relations"]["support"])
                ]
                result["evidenceScope"] = (
                    "Least fixed point of extracted local syntactic references; this is not a proof of Python call resolution or behavior."
                )
        return result

    def search(self, text, path=None):
        result = []
        for relative in [path] if path else self.case["editable"]:
            if relative not in self.case["files"] or not relative.startswith(
                self.case["package"] + "/"
            ):
                raise ValueError("source path outside exposed snapshot")
            for number, line in enumerate(
                (self.root / relative).read_text().splitlines(), 1
            ):
                if text in line:
                    result.append(
                        {"path": relative, "line": number, "text": line[:500]}
                    )
                if len(result) >= 50:
                    return result
        return result

    def edit(self, edits):
        if self.sealed_candidate:
            raise ValueError(
                "independently verified candidate is sealed; source updates require a new task snapshot"
            )
        if not isinstance(edits, list) or not edits:
            raise ValueError("supply a nonempty list of implementation edits")
        updates = {}
        for edit in edits:
            path = edit["path"]
            if path not in self.case["editable"]:
                raise ValueError(
                    "edit only the declared implementation files, never tests or runtime infrastructure"
                )
            original = updates.get(path, (self.root / path).read_text())
            old = edit["old"]
            new = edit["new"]
            if not old or original.count(old) != 1:
                raise ValueError(
                    "replacement must match exactly one current source fragment"
                )
            changed = original.replace(old, new, 1)
            parsed = ast.parse(changed)
            before = ast.parse((self.root / path).read_text())
            imports = lambda tree: {
                ast.dump(n)
                for n in ast.walk(tree)
                if isinstance(n, (ast.Import, ast.ImportFrom))
            }
            if imports(parsed) != imports(before):
                raise ValueError(
                    "this pilot does not admit import changes; use the existing implementation dependencies"
                )
            forbidden = {
                "open",
                "eval",
                "exec",
                "compile",
                "__import__",
                "__builtins__",
                "__loader__",
                "__file__",
                "globals",
                "locals",
            }
            names = lambda tree: {
                n.id for n in ast.walk(tree) if isinstance(n, ast.Name)
            }
            if (names(parsed) - names(before)) & forbidden:
                raise ValueError(
                    "runtime or evaluator introspection is outside the task"
                )
            updates[path] = changed
        for path, text in updates.items():
            (self.root / path).write_text(text)
        self.generation += 1
        self.regenerate()
        return {
            "edited": list(updates),
            "sourceIdentity": self.source_identity,
            "priorEvidenceInvalidated": True,
        }

    def seal_candidate(self, grade):
        expected = len(self.case["expectedTestNames"])
        actual = identity(
            {
                p: hashlib.sha256((self.root / p).read_bytes()).hexdigest()
                for p in self.case["editable"]
            }
        )
        if (
            grade.get("verified") is not True
            or grade.get("kind") != "hidden-grading"
            or grade.get("sourceIdentity") != self.source_identity
            or grade.get("exitCode") != 0
            or actual != self.source_identity
            or expected == 0
            or grade.get("counts")
            != {"passed": expected, "failed": 0, "skipped": 0, "error": 0}
        ):
            raise ValueError(
                "only a current-snapshot independently verified candidate may be sealed"
            )
        destination = self.directory / "verified-candidate"
        destination.mkdir(exist_ok=False)
        for relative in self.case["editable"]:
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(self.root / relative, target)
        copied = identity(
            {
                p: hashlib.sha256((destination / p).read_bytes()).hexdigest()
                for p in self.case["editable"]
            }
        )
        if copied != self.source_identity:
            raise ValueError("candidate source changed while sealing")
        self.sealed_candidate = {
            "sourceIdentity": self.source_identity,
            "graderSha256": self.case["graderSha256"],
            "selectedTestNames": self.case["expectedTestNames"],
            "grade": copy.deepcopy(grade),
            "path": str(destination),
            "scope": "Selected independent grader only; not all repository behavior.",
        }
        (destination / "receipt.json").write_text(
            json.dumps(self.sealed_candidate, indent=2) + "\n"
        )
        return copy.deepcopy(self.sealed_candidate)

    def execute(self, *, grading=False, reproducer=False):
        number = len(list(self.directory.glob("execution-*.log"))) + 1
        run = self.directory / f"execution-{number}"
        run.mkdir()
        xml = run / "tests.xml"
        logpath = self.directory / f"execution-{number}.log"
        python = CORPUS / "execution-environment/bin/python"
        env, sandbox = _prepare_execution_sandbox(self, run, logpath)
        if reproducer:
            code = run / "reproducer.py"
            code.write_text(self.case["reproducer"])
            arguments = [str(code)]
        else:
            targets = self.case["targets"] if grading else self.case["development"]
            text = (
                self.grader.read_text()
                if grading
                else (self.root / self.case["testFile"]).read_text()
            )
            scope = run / "test_scope.py"
            scope.write_text(grading_scope(text, targets))
            (run / "pytest.ini").write_text("[pytest]\n")
            scoped = [
                str(scope) + "::" + target.split("::", 1)[1] for target in targets
            ]
            arguments = [
                "pytest",
                "-vv",
                *scoped,
                "--junitxml=" + str(xml),
                "-c",
                str(run / "pytest.ini"),
                "-p",
                "no:cacheprovider",
                "-s",
            ]
        bootstrap = run / "runner.py"
        bootstrap.write_text(observed_runner(arguments))
        command = [str(python), "-u", str(bootstrap)]
        status, began = _run_bounded_execution(self, logpath, sandbox, command, env)
        text = logpath.read_text()
        visible = "\n".join(
            line
            for line in text.splitlines()
            if not line.startswith(
                ("DEPENDENCY-IMPORT-", "TEST-SCOPE-IMPORT ", "EXECUTION-START")
            )
        )
        if reproducer:
            result = {
                "exitCode": status,
                "observedOutput": visible[-12000:],
                "sourceIdentity": self.source_identity,
                "seconds": time.monotonic() - began,
                "kind": "upstream-reproducer",
            }
            if self.case.get("domainKind") and status == 0:
                observation = json.loads(visible.strip().splitlines()[-1])
                result["domainObservations"] = observation["observations"]
                if self.domain:
                    result["checkedDomainSupport"] = self.domain.observe(
                        self.case["domainKind"],
                        observation["observations"],
                        hashlib.sha256(logpath.read_bytes()).hexdigest(),
                    )
            return result
        return _qualify_execution_receipt(self, xml, status, visible, began, grading)

    def close(self):
        if self.chain:
            self.chain.close()
        if getattr(self, "domain", None):
            self.domain.close()
