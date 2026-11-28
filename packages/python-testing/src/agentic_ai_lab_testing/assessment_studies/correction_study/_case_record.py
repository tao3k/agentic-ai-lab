# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Case record for the correction study study."""

import json


def make_case(label, seed, sources, derived, rules, second, g1, g2, names, complexity):
    sources = json.loads(json.dumps(sources))
    program = {"relations": sources + derived, "rules": rules, "queries": ["answer"]}
    second_program = {
        "relations": sources + derived,
        "rules": second,
        "queries": ["answer"],
    }
    question = (
        "This task has TWO predeclared query obligations over unchanged finite sources. Solve the first now; the second rule set follows later. "
        "Task completion requires BOTH complete answer sets. Evaluate the least fixed point of the explicit rules. Conjunction joins shared variables; "
        "negation is scoped to the exact tuple, not globally to a node or context. Recursive cycles require convergence, not a fixed depth. "
        "Opening/closing labels must match where joined; epsilon includes only the supplied pairs. No external tools are available. "
        'Explanations and Markdown are allowed. Finish with FINAL_JSON: {"answer": ["job", ...]}.\n'
        + json.dumps(program, separators=(",", ":"))
    )
    return {
        "case": f"{label}-{seed}",
        "seed": seed,
        "family": label,
        "sources": sources,
        "program": program,
        "secondProgram": second_program,
        "gold": [sorted(g1), sorted(g2)],
        "intermediates": names,
        "question": question,
        "complexity": complexity,
    }
