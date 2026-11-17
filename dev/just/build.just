# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Build the full Scheme project, including the Core modules Lab imports.
[group('build')]
build:
    just build-core
    just build-qualification-library

# Compile the full product library against the selected Core installation.
# The default build above still requires Core to build successfully first.
# Use the same package environment as the Core publication preparation.
[group('build')]
build-library:
    GERBIL_BUILD_VERBOSE="${GERBIL_BUILD_VERBOSE:-1}" {{ lab_build_env }} timeout --signal=TERM --kill-after=5s 600s ./build.ss compile

# Prepare the selected libraries through their native package declarations.
[group('build')]
build-qualification-library:
    cd "{{ justfile_directory() }}/core" && {{ lab_build_env }} GERBIL_BUILD_VERBOSE="${GERBIL_BUILD_VERBOSE:-1}" {{ gerbil_test_timeout }} 300s gxi {{ gerbil_test_runtime_options }} dev/build-published-modules.ss
    just build-library

# Compile the pinned local Core using Gerbil's incremental outputs.
# Explicit cleanup remains available when replacing a bootstrap artifact cohort.
[group('build')]
build-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" GERBIL_BUILD_VERBOSE="${GERBIL_BUILD_VERBOSE:-1}" {{ gerbil_darwin_env }} gerbil build

# Native clean owns the current spec; discard retired Core package products too.
# Gerbil's native gxc clean leaves dynamic images and removed module names.
[group('build')]
clean-core:
    cd "{{ justfile_directory() }}/core" && {{ lab_build_env }} {{ gerbil_test_timeout }} 600s gerbil {{ gerbil_test_runtime_options }} clean
    rm -rf "{{ agentic_ai_lab_gerbil_path }}/lib/tao3k/yuanxu"
    rm -f "{{ agentic_ai_lab_gerbil_path }}/lib/static/tao3k__yuanxu__"*

# Native clean owns the declared spec; remove retired optional Lab products too.
[group('build')]
clean:
    {{ lab_build_env }} {{ gerbil_test_timeout }} 600s gerbil {{ gerbil_test_runtime_options }} clean
    rm -rf "{{ agentic_ai_lab_gerbil_path }}/lib/tao3k/agentic-ai-lab"
    rm -f "{{ agentic_ai_lab_gerbil_path }}/lib/static/tao3k__agentic-ai-lab__"*

# Build the runtime-C library target.
[group('build')]
build-runtime-c:
    {{ gerbil_darwin_env }} make -C bindings/runtime-c OUT="{{ runtime_c_output }}" runtime

# Build the Bundle v1 C library target.
[group('build')]
build-bundle-v1:
    {{ gerbil_darwin_env }} make -C bindings/runtime-c OUT="{{ runtime_c_output }}" bundle

# Build the single Lean-linked Cedar Runtime Host at an explicit output path (Nix: $out/bin/cedarRuntimeHost).
[group('build')]
build-cedar-runtime-host out:
    python3 packages/automation/build_cedar_runtime_host.py "{{ out }}"

[group('build')]
build-semantic-runtime output:
    python3 bindings/runtime-c/tools/build-semantic.py --output "{{ output }}"

# An explicit AOT caller consumes the published library; it owns no module list.
[group('build')]
build-context-actor-runtime executable:
    {{ gerbil_darwin_env }} gxc -:max-heap=1G,debug=q -O -exe -o '{{executable}}' t/harness/context-actor-runtime-driver.ss

# Focused producer compilation for the existing Durable owner. This is not
# whole-package acceptance; runtime crash receipts bind these exact products.
[group('build')]
build-context-workspace-owner:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gxc {{ gerbil_test_runtime_options }} -O -d "{{ agentic_ai_lab_library_path }}" modules/ai-agentic-context/recovery-observation.ss modules/ai-agentic-context/durable-owner.ss
