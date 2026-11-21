# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Stable model-study envelope and registered experimental protocols."""

SCHEMA_ID = "agentic-ai-lab.model-study.observation"
SCHEMA_VERSION = 1
CORPUS_SHA256 = "7248c6452afba59a1627f82c9fd5763b1fb4bba71513153a303d8edc4abec628"

# Protocol identity describes the intervention; it is not a filename version.
PROTOCOLS = {
    "baseline": {"revision": 1, "arms": ("baseline", "tool")},
    "typed": {"revision": 2, "arms": ("old", "typed")},
    "founded": {"revision": 3, "arms": ("typed", "proof")},
}
CURRENT_PROTOCOL = "founded"
