# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native for the movie study study."""

import json
import os
import subprocess
import sys
from agentic_ai_lab_runtime.reasoning import rows_equal
from ._config import ROOT


def scheme(*arguments):
    env = os.environ.copy()
    env["GERBIL_LOADPATH"] = str(ROOT / ".gerbil/lib") + (
        ":" + env["GERBIL_LOADPATH"] if env.get("GERBIL_LOADPATH") else ""
    )
    env["GERBIL_PATH"] = str(ROOT / ".gerbil")
    env.pop("DEEPSEEK_API_KEY", None)
    invocation = (
        "(begin (import :gerbil-ascent/t/qualification/ascent-movie-cast-test) (main "
        + " ".join(json.dumps(str(arg), ensure_ascii=False) for arg in arguments)
        + ") (exit 0))"
    )
    # Report actual completed compiler imports while the scheme root expands.
    code = (
        """(import :gerbil/expander)
(let ((loader (current-expander-module-import)) (count 0))
 (parameterize ((current-expander-module-import
  (lambda (path reload?)
   (let (context (loader path reload?))
    (when context (set! count (+ count 1))
     (when (zero? (modulo count 8)) (displayln "MOVIE-IMPORTS " count " " (expander-context-id context)) (force-output))) context))))
  (eval '\n"""
        + invocation
        + ")))"
    )
    command = [
        sys.executable,
        "-m",
        "agentic_ai_lab_testing.assessment_studies.supervision",
        "--",
        "timeout",
        "120s",
        "gxi",
        "-:max-heap=2G,debug=q",
        "-e",
        code,
    ]
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def ffi_grade(engine, wire, preview, plan, item, raw):
    """Protocol adaptation only; Scheme executes and compares answers."""
    cases = [
        c
        for c in plan["cases"]
        if (
            c["id"] == item["id"]
            if item["arm"] == "baseline"
            else c["family"] == item["id"]
        )
    ]

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate prediction key")
            result[key] = value
        return result

    try:
        value = json.loads(raw, object_pairs_hook=pairs)
        if item["arm"] == "baseline":
            if not isinstance(value, list) or not all(
                isinstance(x, str) for x in value
            ):
                raise ValueError("expected actor array")
            expected = json.loads(
                (preview / "private" / (item["id"] + ".answer.json")).read_text()
            )
            return [
                {
                    "id": item["id"],
                    "correct": rows_equal(
                        [[x] for x in value], [[x] for x in expected]
                    ),
                }
            ]
        if (
            not isinstance(value, dict)
            or set(value) != {"combine", "exclude_scope"}
            or value["combine"] not in ("any", "all")
            or value["exclude_scope"] not in ("none", "left", "both")
        ):
            raise ValueError("expected finite query contract")
        key = cases[0]["id"] + ":" + value["combine"] + ":" + value["exclude_scope"]
        observations = []
        with engine.open(wire[key]) as session:
            for index, case in enumerate(cases):
                if index:
                    session.replace(
                        [
                            {"relation": relation, "rows": [[case[field]]]}
                            for relation, field in (
                                ("left_film", "left"),
                                ("right_film", "right"),
                                ("blocked_actor", "blocked"),
                            )
                        ]
                    )
                result = session.run()
                expected = json.loads(
                    (preview / "private" / (case["id"] + ".answer.json")).read_text()
                )
                equal = rows_equal(
                    result["relations"]["actor_answer"], [[x] for x in expected]
                )
                observations.append(
                    {
                        "id": case["id"],
                        "correct": bool(result["complete"] and equal),
                        "scheme": result,
                    }
                )
            return observations
    except (ValueError, TypeError, KeyError) as error:
        return [
            {"id": case["id"], "correct": False, "protocolError": str(error)}
            for case in cases
        ]
