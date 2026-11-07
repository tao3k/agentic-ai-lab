# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Threshold evaluation for build profile performance gates."""

from __future__ import annotations

from ._build_profile_model import BuildProfile, ProfileGateFailure


def evaluate_profile_thresholds(
    profile: BuildProfile,
    *,
    max_wall_seconds: float | None = None,
    max_package_seconds: float | None = None,
    max_external_gap_seconds: float | None = None,
) -> tuple[ProfileGateFailure, ...]:
    thresholds = (
        ("wall", profile.wall_micros, _seconds_to_micros(max_wall_seconds)),
        ("package", profile.package_micros, _seconds_to_micros(max_package_seconds)),
        (
            "external-gap",
            profile.external_gap_micros,
            _seconds_to_micros(max_external_gap_seconds),
        ),
    )
    failures = [
        ProfileGateFailure(metric, actual, maximum)
        for metric, actual, maximum in thresholds
        if maximum is not None and actual > maximum
    ]
    return tuple(failures)


def _seconds_to_micros(seconds: float | None) -> int | None:
    if seconds is None:
        return None
    return int(seconds * 1_000_000)
