# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public composition lifecycle benchmark surface."""

from ._composition_lifecycle_receipt import (
    COMPOSITION_LIFECYCLE_SCHEMA,
    CompositionLatencySummary,
    CompositionLifecycleBenchmark,
)
from ._composition_lifecycle_runner import (
    DEFAULT_COMPOSITION_POPULATIONS,
    run_composition_benchmarks,
)
from ._composition_lifecycle_workload import ArrivalSchedule

__all__ = (
    "DEFAULT_COMPOSITION_POPULATIONS",
    "ArrivalSchedule",
    "COMPOSITION_LIFECYCLE_SCHEMA",
    "CompositionLatencySummary",
    "CompositionLifecycleBenchmark",
    "run_composition_benchmarks",
)
