# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
import shutil
import subprocess
from functools import lru_cache
from pathlib import Path

import pytest


_SCHEME_PAYLOAD_SEPARATOR = b"\n--agentic-ai-lab-runtime-envelope--\n"


@lru_cache(maxsize=1)
def _scheme_generated_durable_payloads() -> tuple[bytes, bytes]:
    if shutil.which("gxi") is None:
        pytest.skip("Gerbil gxi is not available")
    repo_root = Path(__file__).resolve().parents[4]
    if not (repo_root / ".gerbil" / "lib").exists():
        pytest.skip("package-local Gerbil build output is not available")

    env = os.environ.copy()
    env.setdefault("GERBIL_LOADPATH", ".gerbil/lib")
    result = subprocess.run(
        [
            "gxi",
            "-:max-heap=1G,debug=q",
            "-e",
            (
                "(begin "
                "(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy "
                ":agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy-manifest "
                ":agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store "
                ":agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend "
                ":agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/runtime-manifest) "
                "(define policy "
                "(agentic-ai-lab-durable-policy "
                "(quote durable/python-runtime-envelope) "
                "(quote shared))) "
                "(display "
                "(agentic-ai-lab-durable-policy-runtime-manifest-string policy)) "
                "(display \"\\n--agentic-ai-lab-runtime-envelope--\\n\") "
                "(display "
                "(agentic-ai-lab-durable-runtime-manifest-string "
                "policy "
                "agentic-ai-lab-durable-runtime-store-contract/default "
                "agentic-ai-lab-durable-runtime-store-backend/default)))"
            ),
        ],
        cwd=repo_root,
        env=env,
        check=True,
        capture_output=True,
        timeout=90,
    )
    policy_manifest, runtime_envelope = result.stdout.split(
        _SCHEME_PAYLOAD_SEPARATOR,
        1,
    )
    return policy_manifest, runtime_envelope


def scheme_durable_policy_manifest_bytes() -> bytes:
    return _scheme_generated_durable_payloads()[0]


def scheme_durable_runtime_envelope_bytes() -> bytes:
    return _scheme_generated_durable_payloads()[1]
