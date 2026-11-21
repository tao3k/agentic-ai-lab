# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tools for the repository model study study."""


def tool_definitions():
    definitions = [
        (
            "read_source",
            "Read parent/current implementation source. Lines are one-based, at most 200 per read. Scheme arms also return checked local syntactic support.",
            {
                "path": {"type": "string"},
                "start": {"type": "integer"},
                "end": {"type": "integer"},
            },
        ),
        (
            "search_source",
            "Find literal text in implementation files; omitted path searches the declared implementation surfaces.",
            {"text": {"type": "string"}, "path": {"type": "string"}},
        ),
        (
            "edit_source",
            "Apply edits to implementation files: each edit has path, old and new. old must match one current fragment. Source changes invalidate checked evidence.",
            {
                "edits": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "path": {"type": "string"},
                            "old": {"type": "string"},
                            "new": {"type": "string"},
                        },
                    },
                }
            },
        ),
        (
            "run_reproducer",
            "Execute the original upstream bug reproducer against the current implementation.",
            {},
        ),
        (
            "run_checks",
            "Run existing visible development controls against current code.",
            {},
        ),
        (
            "submit_patch",
            "Grade the current repair independently. Returns counts and a verdict, without hidden test contents or the gold repair.",
            {},
        ),
    ]
    return [
        {
            "type": "function",
            "name": name,
            "description": description,
            "parameters": {"type": "object", "properties": properties},
        }
        for name, description, properties in definitions
    ]
