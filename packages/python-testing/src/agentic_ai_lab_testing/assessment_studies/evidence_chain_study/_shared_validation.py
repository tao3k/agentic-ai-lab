# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared validation for the evidence chain study study."""

from ._config import SHARED_LABEL_TOOL
from ._shared_cases import shared_truth


def shared_validate_label(text, item, task, supplied, prior, *, supplied_absent=()):
    import re

    required = {"quote", "occurrence", "category", "atom", "premises"}
    assert isinstance(item, dict) and set(item) == required, "label schema"
    quote = item["quote"]
    occurrence = item["occurrence"]
    category = item["category"]
    assert (
        isinstance(quote, str) and quote and type(occurrence) is int and occurrence >= 0
    )
    assert (
        category
        in SHARED_LABEL_TOOL["parameters"]["properties"]["episodes"]["items"][
            "properties"
        ]["category"]["enum"]
    )
    at = -1
    for _ in range(occurrence + 1):
        at = text.find(quote, at + 1)
        assert at >= 0, "quote not verbatim"
    result = {
        **item,
        "span": [at, at + len(quote)],
        "qualifiedPositive": False,
        "repeatFact": False,
        "exactRepeat": False,
        "newConsequence": False,
    }
    if category in ("arithmetic", "ambiguous"):
        assert item["atom"] == [] and item["premises"] == [], (
            "nonsemantic category must not assign atoms"
        )
        return result
    atom = item["atom"]
    premises = item["premises"]
    truth = shared_truth(task, atom)
    numbers = {int(x) for x in re.findall(r"(?<![\w.])-?\d+(?![\w.])", quote)}
    assert all(n in numbers for a in [atom, *premises] for n in a[1:]), (
        "endpoints absent from quote"
    )
    if category == "absent_premise_consumed":
        assert not truth and atom in supplied_absent, (
            "negative premise not previously supplied as finite-absent"
        )
        assert not premises and re.search(
            r"\b(native|evidence|given|conclusion)\b", quote, re.I
        ), (
            "negative use must explicitly reference supplied evidence, not invent a proof"
        )
        result["negativePremiseConsumed"] = True
        return result
    if category == "absence_recheck":
        assert not truth and re.search(
            r"\b(no|not|cannot|unreachable|absent|missing|false)\b", quote, re.I
        ), "unsupported absence label"
        result["absenceArgumentCompletenessVerified"] = False
        return result
    assert truth, "false positive conclusion"
    if category == "premise_consumed":
        assert atom in supplied or any(
            p["atom"] == atom and p["qualifiedPositive"] for p in prior
        ), "premise not established"
        return result
    assert premises and atom not in premises, "empty or circular support"
    assert all(shared_truth(task, p) for p in premises), "false stated premise"
    if atom[0] == "path":
        assert len(premises) > 1 or premises[0][0] == "edge", (
            "reference alone is not derivation"
        )
        cursor = atom[1]
        for p in premises:
            assert p[0] in ("edge", "path") and p[1] == cursor, "nonchain support"
            cursor = p[2]
        assert cursor == atom[2], "wrong chain endpoint"
    elif atom[0] == "ready":
        n = next(n for n in task["needs"] if n[0] == atom[1])
        assert premises == [["path", n[1], n[2]], ["path", n[3], n[4]]], (
            "wrong conjunction support"
        )
    else:
        raise ValueError("source assertion is not a derived consequence")
    previous = [p for p in prior if p["qualifiedPositive"] and p["atom"] == atom]
    result.update(
        qualifiedPositive=True,
        repeatFact=bool(previous),
        exactRepeat=any(p["premises"] == premises for p in previous),
        newConsequence=not previous and atom not in supplied,
        suppliedPremiseRederived=atom in supplied,
    )
    return result
