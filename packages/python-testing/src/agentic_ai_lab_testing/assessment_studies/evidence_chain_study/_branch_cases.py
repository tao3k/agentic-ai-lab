# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch cases for the evidence chain study study."""

from ._branch_contracts import branch_candidates
from ._shared_cases import shared_truth


def branch_tasks():
    tasks = []
    for case in range(2):
        edges = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [0, 6], [6, 7], [7, 5]]
        items = []
        needs = []
        for i in range(16):
            start = [0, 2, 6][i % 3]
            a = 20 + i
            b = 100 + i
            end = 200 + i
            valid = i not in ([3, 7, 11, 15] if case == 0 else [2, 6, 10, 14])
            edges.extend([[a, b], [b, end]] if valid else [[end, b], [b, a]])
            items.append(
                {
                    "id": i,
                    "paths": [[start, 5], [a, end]],
                    "group": i % 4,
                    "weight": 5 + (i * 7 + case * 3) % 14,
                    "risk": 2 + (i * 11 + case * 5) % 12,
                    "value": 15 + (i * 17 + case * 13) % 43,
                }
            )
            needs.append([i, start, 5, a, end])
        bonuses = [
            {"pair": [i, j], "value": 7 + (i + j) % 11}
            for i in range(16)
            for j in range(i + 1, 16)
            if (i * 3 + j) % 7 == 0
        ]
        task = {
            "id": f"sibling-search-{case}",
            "edges": edges,
            "needs": needs,
            "items": items,
            "bonuses": bonuses,
            "sharedAtom": ["path", 0, 5],
            "branches": [],
        }
        eligible = [x["id"] for x in items if shared_truth(task, ["ready", x["id"]])]
        for turn in range(6):
            branch = {
                "id": turn,
                "weightLimit": 49 + turn % 3 * 4,
                "riskLimit": 29 + turn % 3 * 3,
                "required": eligible[turn],
                "excluded": eligible[-1 - turn],
            }
            feasible = branch_candidates(task, branch)
            assert len(feasible) > 1 and min(s for s, _ in feasible) < max(
                s for s, _ in feasible
            )
            branch["start"] = min(feasible)[
                1
            ]  # Deliberately nonoptimal; never adjusted after freezing.
            task["branches"].append(branch)
        tasks.append(task)
    return tasks


def branch_literal_episodes(text, task, supplied, prior, turn, step):
    """Exhaustive text partition plus conservative explicit-chain observations.

    The scanner has finite grammars, not a general natural-language parser.
    Every character is assigned to a line; unresolved path language is visible.
    It never constructs a missing edge from the fixture to finish a quote.
    """
    import re

    lines = []
    offset = 0
    events = []
    arrow = re.compile(r"(?<![\w.])\d+(?:\s*(?:->|→|⇒)\s*\d+)+")
    pairs = re.compile(r"\[\s*(\d+)\s*,\s*(\d+)\s*\]")
    via = re.compile(r"(\d+)\s*(?:->|→|to)\s*(\d+)\s+via\s+((?:\d+\s*,\s*)+\d+)", re.I)
    semantic = re.compile(
        r"\b(path|paths|reachab\w*|valid|invalid|infeasible|absent|ready|edge|edges|exists|via|true|false)\b|->|→",
        re.I,
    )
    for line in text.splitlines(keepends=True):
        chains = []
        for match in arrow.finditer(line):
            ns = [int(x) for x in re.findall(r"\d+", match.group())]
            if len(ns) >= 3:
                chains.append((match.start(), match.end(), ns))
        for match in via.finditer(line):
            ns = [int(x) for x in re.findall(r"\d+", match.group(3))]
            if (
                len(ns) >= 3
                and ns[0] == int(match.group(1))
                and ns[-1] == int(match.group(2))
            ):
                chains.append((match.start(), match.end(), ns))
        matches = list(pairs.finditer(line))
        for i, m in enumerate(matches):
            # A maximal adjacent literal edge list must itself form a chain.
            if i and re.fullmatch(r"[\s,;]*", line[matches[i - 1].end() : m.start()]):
                continue
            j = i
            ns = [int(m.group(1)), int(m.group(2))]
            while (
                j + 1 < len(matches)
                and re.fullmatch(
                    r"[\s,;]*", line[matches[j].end() : matches[j + 1].start()]
                )
                and int(matches[j + 1].group(1)) == ns[-1]
            ):
                j += 1
                ns.append(int(matches[j].group(2)))
            if j > i and semantic.search(line):
                chains.append((m.start(), matches[j].end(), ns))
        seen = set()
        for start, end, ns in sorted(chains):
            atom = ["path", ns[0], ns[-1]]
            premises = [["edge", a, b] for a, b in zip(ns, ns[1:])]
            key = (start, end, tuple(ns))
            if key in seen:
                continue
            seen.add(key)
            if not all(shared_truth(task, x) for x in premises):
                continue
            old = [e for e in prior + events if e["atom"] == atom]
            event = {
                "quote": line[start:end],
                "span": [offset + start, offset + end],
                "atom": atom,
                "premises": premises,
                "turn": turn,
                "step": step,
                "qualifiedPositive": True,
                "crossBranchRepeat": any(e["turn"] != turn for e in old),
                "sameBranchRepeat": any(
                    e["turn"] == turn and e["step"] != step for e in old
                ),
                "withinResponseRepeat": any(
                    e["turn"] == turn and e["step"] == step for e in old
                ),
                "exactRepeat": any(e["premises"] == premises for e in old),
                "suppliedPremiseRederived": atom in supplied,
                "newConsequence": not old and atom not in supplied,
            }
            # Overlapping textual encodings are one occurrence, not two derivations.
            if any(
                e["span"][0] < event["span"][1] and event["span"][0] < e["span"][1]
                for e in events
            ):
                continue
            events.append(event)
        line_events = [e for e in events if offset <= e["span"][0] < offset + len(line)]
        lines.append(
            {
                "span": [offset, offset + len(line)],
                "quote": line,
                "category": "explicit_chain"
                if line_events
                else "unresolved_semantic"
                if semantic.search(line)
                else "other_visible_text",
            }
        )
        offset += len(line)
    assert offset == len(text) and "".join(l["quote"] for l in lines) == text
    return {
        "characters": len(text),
        "coveredCharacters": offset,
        "partitions": lines,
        "episodes": events,
        "unresolvedSemanticLines": sum(
            l["category"] == "unresolved_semantic" for l in lines
        ),
    }
