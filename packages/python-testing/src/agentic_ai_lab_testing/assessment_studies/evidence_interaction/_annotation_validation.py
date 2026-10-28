# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Validate source anchored annotation episodes against both native judges."

import re
from ._artifacts import canonical
from ._workload import independent_atom


def anchor(text, quote, occurrence):
    if (
        not isinstance(quote, str)
        or not quote
        or type(occurrence) is not int
        or occurrence < 0
    ):
        raise ValueError("invalid quote occurrence")
    start = 0
    for _ in range(occurrence + 1):
        pos = text.find(quote, start)
        if pos < 0:
            raise ValueError("quote missing verbatim")
        start = pos + 1
    return [pos, pos + len(quote)]


def validate_episode(text, item, task, native, judge, memo):
    span = anchor(text, item["quote"], item["occurrence"])
    if (
        item["kind"]
        not in ("derive", "reuse", "mention", "conditional_recheck", "uncertain")
        or type(item["polarity"]) is not bool
    ):
        raise ValueError("invalid label category")
    atom = item["atom"]
    premises = item["premises"]
    native_check = native.call(op="episode", atom=atom, premises=premises)
    truth = independent_atom(judge, task, atom, memo)
    if truth != native_check["present"]:
        raise ValueError("atomic independent checker disagreement")
    for premise in premises:
        if not independent_atom(judge, task, premise, memo):
            raise ValueError("false stated premise")
    numbers = {int(x) for x in re.findall(r"(?<![\w.])-?\d+(?![\w.])", item["quote"])}
    # F0 is a literal ID even though its numeric suffix is attached to a letter.
    literal_ids = {
        int(x)
        for x in re.findall(r"\b(?:F\s*|fragment\s+)(\d+)\b", item["quote"], flags=re.I)
    }
    literal_ids |= {
        int(x)
        for x in re.findall(
            r"\bready\s*[([]\s*(\d+)\s*[)\]]", item["quote"], flags=re.I
        )
    }
    numbers |= literal_ids
    if any(x not in numbers for claim in [atom, *premises] for x in claim[1:]):
        raise ValueError("claimed endpoints absent from literal quote")
    if atom[0] == "ready" and atom[1] not in literal_ids:
        raise ValueError("fragment ID absent or mismatched; no silent repair")
    qualified = bool(
        item["kind"] == "derive"
        and item["polarity"] is True
        and truth
        and native_check["supportQualified"]
    )
    return {
        **item,
        "span": span,
        "nativeTruth": truth,
        "truthMatches": truth == item["polarity"],
        "supportQualified": native_check["supportQualified"],
        "qualifiedPositiveDerivation": qualified,
        "claimKey": [canonical(atom), canonical(premises), item["polarity"]],
        "prior": None,
        "definiteRepeat": False,
    }


def _admit_annotation_episodes(
    raw, text, task, native, judge, memo, measurement, call, result
):
    """Own the admit annotation episodes phase and retain its evidence checks."""
    for i, item in enumerate(raw):
        try:
            episode = validate_episode(text, item, task, native, judge, memo)
            episode.update(
                index=len(measurement["accepted"]),
                turn=call["turn"],
                textSha256=result["textSha256"],
                atGrossTokens=call.get("atGrossTokens"),
            )
            if (
                result["accepted"]
                and episode["span"][0] < result["accepted"][-1]["span"][0]
            ):
                raise ValueError("out_of_order_quote")
            previous = next(
                (
                    p
                    for p in measurement["accepted"]
                    if p["qualifiedPositiveDerivation"]
                    and p["claimKey"] == episode["claimKey"]
                    and (
                        p["turn"] < episode["turn"]
                        or p["span"][1] <= episode["span"][0]
                    )
                ),
                None,
            )
            if episode["qualifiedPositiveDerivation"] and previous:
                episode["prior"] = {
                    "turn": previous["turn"],
                    "index": previous["index"],
                }
                episode["definiteRepeat"] = True
            result["accepted"].append(episode)
            measurement["accepted"].append(episode)
        except (
            ValueError,
            KeyError,
            TypeError,
            IndexError,
        ) as error:
            rejection = {
                "turn": call["turn"],
                "rawIndex": i,
                "item": item,
                "reason": str(error),
            }
            result["rejected"].append(rejection)
            measurement["rejected"].append(rejection)
