# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Sources for the movie study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

import hashlib
import re
from ._config import PRODUCERS, ROOT


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identities():
    paths = {path: ROOT / path for path in PRODUCERS}
    for directory in ("core", "table", "program", "applications"):
        for source in (ROOT / directory).glob("*.ss"):
            paths[str(source.relative_to(ROOT))] = source
        for artifact in (ROOT / ".gerbil/lib/gerbil-ascent" / directory).glob("*"):
            if artifact.is_file() and (
                re.fullmatch(r"\.o\d*", artifact.suffix)
                or artifact.suffix in (".ssi", ".scm")
                or artifact.name.endswith(".ssxi.ss")
            ):
                paths[str(artifact.relative_to(ROOT))] = artifact
    return _source_hashes({path: file for path, file in paths.items()})
