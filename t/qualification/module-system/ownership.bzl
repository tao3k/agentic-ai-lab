# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Single source of truth for RFC45 module-system qualification ownership."""

OWNER_MAP_SCHEMA = "agentic-ai-lab.module-system-qualification-ownership.v1"

DESCENDANT_BOUNDARIES = [
    "packages/lambda-aitia",
    "packages/lambda-episteme",
]

OWNER_MAP_ROWS = [
    {
        "row_id": "rfc45-01-mix-module-expansion",
        "rfc": "45-01",
        "source_path": "core/profile-composition/profile-bundle.ss",
        "source_symbol": "compose",
        "source_kind": "function",
        "test_path": "t/profile-bundle-test.ss",
        "test_symbol": "profile-bundle-test",
        "target_name": "rfc45_01_mix_sources",
    },
    {
        "row_id": "rfc45-02-g0-decision",
        "rfc": "45-02",
        "source_path": "modules/workflow/qualification/module-system/g0.ss",
        "source_symbol": "agentic-ai-lab-g0-resolve",
        "source_kind": "function",
        "test_path": "t/qualification/module-system/owner-contract-test.ss",
        "test_symbol": "owner-contract-test",
        "target_name": "rfc45_02_sources",
    },
    {
        "row_id": "rfc45-03-runtime-context-recovery",
        "rfc": "45-03",
        "source_path": "modules/session/runtime-context-recovery.ss",
        "source_symbol": "agentic-ai-lab-runtime-context",
        "source_kind": "function",
        "test_path": "t/qualification/module-system/owner-contract-test.ss",
        "test_symbol": "owner-contract-test",
        "target_name": "rfc45_03_sources",
    },
    {
        "row_id": "rfc45-04-observability-snapshot",
        "rfc": "45-04",
        "source_path": "core/module-system/observability/presentation.ss",
        "source_symbol": "yuanxu-module-presentation-trace",
        "source_kind": "function",
        "test_path": "t/module-system-observability-test.ss",
        "test_symbol": "module-system-observability-test",
        "target_name": "rfc45_04_sources",
    },
    {
        "row_id": "rfc45-06-gerbil-poo-consumption",
        "rfc": "45-06",
        "source_path": "modules/workflow/qualification/module-system/gerbil-poo-consumption.ss",
        "source_symbol": "agentic-ai-lab-gerbil-poo-consumption-manifest",
        "source_kind": "function",
        "test_path": "t/qualification/module-system/owner-contract-test.ss",
        "test_symbol": "owner-contract-test",
        "target_name": "rfc45_06_sources",
    },
    {
        "row_id": "rfc45-07-public-composition",
        "rfc": "45-07",
        "source_path": "modules/workflow/scenario/composition-syntax.ss",
        "source_symbol": "user-composition",
        "source_kind": "macro",
        "test_path": "t/profile-binding-syntax-test.ss",
        "test_symbol": "profile-binding-syntax-test",
        "target_name": "rfc45_07_composition_sources",
    },
]

QUALIFICATION_TARGET = "//t/qualification/module-system:owner_map_tests"
