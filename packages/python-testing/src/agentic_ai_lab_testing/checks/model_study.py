# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native fixed-fixture checks shared by paid and offline model studies."""

from __future__ import annotations

from ..model import CaseContext
from ..model_study.runner import corpus, observations
from ..model_study.fixtures import stratified_observation


def native_fixtures(context: CaseContext) -> None:
    expected = {case["id"] for case in corpus()}
    actual, _elapsed = observations(
        context.module_root("gerbil-ascent"), context.repository_root,
    )
    if set(actual) != expected:
        raise AssertionError("model study fixture catalog is incomplete")
    stratified_observation(
        context.module_root("gerbil-ascent"), context.repository_root,
    )
