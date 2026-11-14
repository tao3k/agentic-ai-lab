# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the assessment formal study."""

from __future__ import annotations


from pathlib import Path
from ..assessment_models import MODEL_ORDER

ROOT = Path.cwd().resolve()

SECONDS = 15 * 60

GROUPS = {"EvidenceAssessment": MODEL_ORDER}
