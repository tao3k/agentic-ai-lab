# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_proof.lean_emit import manifest_to_lean
from agentic_ai_lab_proof.model import canonical_loop_engine_manifest


def test_emitter_uses_lean_constructors_not_raw_strings() -> None:
    lean = manifest_to_lean(canonical_loop_engine_manifest(), "AgenticAILabProof.Generated.LoopEngine")
    assert "ObligationName.uiConfigWellFormed" in lean
    assert "RuntimeExecution.inert" in lean
    assert "requiredObligationMask := 31" in lean
    assert '"ui-config-well-formed"' not in lean
    assert "generatedManifest_valid" in lean
