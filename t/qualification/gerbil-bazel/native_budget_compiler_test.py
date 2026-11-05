#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Require both native compiler observation and guarded build completion."""

import json
import sys
from shared_gerbil_capability_test import resolve_runfile

receipt = json.loads(resolve_runfile(sys.argv[1]).read_text())
log = resolve_runfile(sys.argv[2]).read_text()
assert receipt["status"] == "ok", receipt
assert receipt["libraryOutputRequired"] is True, receipt
assert receipt["resourceGuard"]["outcome"] == "completed", receipt
assert receipt["resourceGuard"]["requestedBuildCoreCount"] == 12, receipt
assert receipt["resourceGuard"]["effectiveBuildCoreCount"] == 1, receipt
assert "NATIVE-COMPILER-BUDGET-OK available-cores=1 max-heap=256M" in log, log
print("NATIVE-COMPILER-BUDGET-PASS")
