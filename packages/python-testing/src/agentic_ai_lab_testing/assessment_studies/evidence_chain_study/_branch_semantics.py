# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch semantics for the evidence chain study study."""

from ._config import SEMANTIC_BLOCK_TAGS, SEMANTIC_LINE_CATEGORIES


def branch_semantic_validate(text, payload):
    """Require a label for every actual line; missing/unclear semantics fail closed."""
    assert isinstance(payload, dict) and set(payload) == {
        "lineCategories",
        "episodes",
    }, "semantic schema"
    lines = text.splitlines(keepends=True)
    labels = payload["lineCategories"]
    assert isinstance(labels, list) and len(labels) == len(lines), (
        "semantic line coverage"
    )
    spans = []
    offset = 0
    for i, (line, category) in enumerate(zip(lines, labels)):
        assert category in SEMANTIC_LINE_CATEGORIES, "unknown semantic category"
        spans.append(
            {"line": i, "span": [offset, offset + len(line)], "category": category}
        )
        offset += len(line)
    assert offset == len(text)
    return spans


def branch_semantic_partition(text, episodes):
    """Code owns coverage; model proposals own only independently admitted quotes."""
    partitions = []
    cursor = 0
    for e in episodes:
        start, end = e["span"]
        assert cursor <= start < end <= len(text) and text[start:end] == e["quote"], (
            "quote coverage shape"
        )
        if cursor < start:
            partitions.append(
                {"span": [cursor, start], "category": "unreviewed_semantics"}
            )
        partitions.append({"span": [start, end], "category": "admitted_quote_proposal"})
        cursor = end
    if cursor < len(text):
        partitions.append(
            {"span": [cursor, len(text)], "category": "unreviewed_semantics"}
        )
    assert sum(p["span"][1] - p["span"][0] for p in partitions) == len(text)
    return partitions


def branch_semantic_summary(text, episodes):
    """Separate admitted quote evidence from exhaustive repetition claims.

    A negative assertion's truth does not certify a new absence argument.
    Arithmetic and mentions do not certify exploration depth. Unreviewed text
    leaves whole-trace repetition unknown even when no accepted proof repeats.
    """
    partition = branch_semantic_partition(text, episodes)
    counts = {
        k: 0
        for k in (
            "positive_fact_use",
            "negative_fact_use",
            "positive_reconstruction_proposal",
            "new_positive_inference_proposal",
            "negative_statement_unresolved",
            "other_proposal",
        )
    }
    for e in episodes:
        category = e["category"]
        if category == "premise_consumed":
            role = "positive_fact_use"
        elif category == "absent_premise_consumed":
            role = "negative_fact_use"
        elif category == "absence_recheck":
            role = "negative_statement_unresolved"
        elif e.get("qualifiedPositive"):
            role = (
                "new_positive_inference_proposal"
                if e.get("newConsequence")
                else "positive_reconstruction_proposal"
            )
        else:
            role = "other_proposal"
        counts[role] += 1
    return {
        "admittedProposalCounts": counts,
        "characterPartition": partition,
        "unreviewedCharacters": sum(
            p["span"][1] - p["span"][0]
            for p in partition
            if p["category"] == "unreviewed_semantics"
        ),
        "wholeTraceRepeatedDerivations": None,
        "negativeRederivations": None,
        "explorationDepth": None,
        "fullSemanticRecallCertified": False,
    }


def branch_semantic_blocks(text, limit):
    """Own immutable review boundaries locally; annotators never count lines."""
    assert type(limit) is int and limit > 0
    blocks = []
    start = 0
    while start < len(text):
        end = min(start + limit, len(text))
        if end < len(text):
            boundary = text.rfind("\n", start + limit // 2, end)
            if boundary >= 0:
                end = boundary + 1
        blocks.append(
            {"id": len(blocks), "span": [start, end], "text": text[start:end]}
        )
        start = end
    assert "".join(b["text"] for b in blocks) == text
    return blocks


def branch_semantic_block_admit(blocks, proposals):
    """Coverage of review proposals is distinct from semantic recall or truth."""
    assert isinstance(proposals, list), "block review schema"
    indexed = {}
    for p in proposals:
        assert set(p) == {"id", "tags"} and type(p["id"]) is int, "block review schema"
        assert 0 <= p["id"] < len(blocks) and p["id"] not in indexed, (
            "duplicate or unknown block"
        )
        assert (
            isinstance(p["tags"], list)
            and p["tags"]
            and len(set(p["tags"])) == len(p["tags"])
        ), "block tags shape"
        assert all(t in SEMANTIC_BLOCK_TAGS for t in p["tags"]), "unknown semantic tag"
        indexed[p["id"]] = p["tags"]
    assert len(indexed) == len(blocks), "missing block review; unreviewed is not zero"
    return [
        {
            "id": b["id"],
            "span": b["span"],
            "tags": indexed[b["id"]],
            "status": "unclear"
            if "unclear" in indexed[b["id"]]
            else "model_review_proposal",
        }
        for b in blocks
    ]
