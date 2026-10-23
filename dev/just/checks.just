# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Query the complete Bazel target graph without executing actions.
[group('discovery')]
query:
    {{ bazel }} query //...

# Run the cold native lifecycle in order; stop on the first failure.
[group('check')]
rebuild:
    just clean
    just deps
    just build
    just test

# Run the native Scheme build and ordinary-test convergence gate.
[group('check')]
check: build test

# Admit gerbil-parser through Agentic AI Lab's current V19 dependency environment.
# The sibling remains the parser source owner; qualification imports only the
# demanded modules and never builds a second stale package cache.
_prepare-gerbil-parser:
    test -f "{{ gerbil_parser_dir }}/gerbil.pkg"
    GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ gerbil_parser_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil interactive -e '(begin (import :gerbil-parser/src/runtime/artifact) (displayln "gerbil-parser-v19-ready"))'

[group('check')]
check-governance-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group governance

# Validate the repository and published-package license contract.
[group('check')]
check-license-contract:
    python3 packages/automation/check_license_contract.py
    python3 -m unittest discover -s packages/automation/tests -p 'test_*.py'

# Validate every first-party manifest and Runtime ABI projection against VERSION.
[group('check')]
check-version-contract:
    python3 packages/automation/check_version_contract.py

# Validate that gerbil.pkg direct pins and every Bazel projection agree.
[group('check')]
check-gerbil-dependency-contract:
    python3 packages/automation/gerbil_dependency_pin.py check

# Bootstrap the expander in Gxi, then use the upstream GxTest entry point.
# No private assertion runner; require all Cases and the final harness receipt.
[group('check')]
check-search-attempt-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-attempt-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 8
    grep -Fx 'MODULE-OK t/search-attempt-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-dag-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-engine-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 8
    grep -Fx 'MODULE-OK t/search-engine-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-framework-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-framework-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 6
    grep -Fx 'MODULE-OK t/search-framework-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-evidence-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-evidence-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 10
    grep -Fx 'MODULE-OK t/search-evidence-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

# Native Core build projection must load without an ASP build facade.
[group('check')]
check-production-build:
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxi {{ gerbil_test_runtime_options }} build.ss spec
