# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the complex movie study study."""

from pathlib import Path

ROOT = Path.cwd().resolve()

FIXTURE = ROOT / "t/qualification/fixtures/complex-movie/source.json"

TYPES = {
    "cast": ["Film", "Actor"],
    "directed": ["Film", "Director"],
    "citizen": ["Director", "Country"],
    "anchor": ["Actor"],
    "eligible": ["Country", "Film", "Director", "Actor"],
    "coactor": ["Actor", "Film", "Actor"],
    "answer": ["Actor"],
}
