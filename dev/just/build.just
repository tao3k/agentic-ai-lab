# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Build the full Scheme project through the explicit development entry.
[group('build')]
build:
    just build-core
    just build-library

# Compile the full product library against the selected Core installation.
# The default build above still requires Core to build successfully first.
[group('build')]
build-library:
    GERBIL_BUILD_VERBOSE="${GERBIL_BUILD_VERBOSE:-1}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 600s ./build-development.ss compile

# Compile the pinned local Core using Gerbil's incremental outputs.
# Explicit cleanup remains available when replacing a bootstrap artifact cohort.
[group('build')]
build-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" GERBIL_BUILD_VERBOSE="${GERBIL_BUILD_VERBOSE:-1}" {{ gerbil_darwin_env }} gerbil build

# Clean only Core outputs; dependency source checkouts stay intact.
[group('build')]
clean-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil clean

# Clean the same explicit development build artifacts.
[group('build')]
clean:
    {{ gerbil_darwin_env }} ./build-development.ss clean

# Incrementally build the canonical Scheme project through a persistent Bazel development root.
[group('build')]
build-dev:
    {{ bazel }} run {{ gerbil_dev_compile }}

# Build the runtime-C library target.
[group('build')]
build-runtime-c:
    {{ bazel }} build {{ runtime_c_library }}

# Build the Bundle v1 C library target.
[group('build')]
build-bundle-v1:
    {{ bazel }} build {{ bundle_v1_library }}

# Build the single Lean-linked Cedar Runtime Host at an explicit output path (Nix: $out/bin/cedarRuntimeHost).
[group('build')]
build-cedar-runtime-host out:
    python3 packages/automation/build_cedar_runtime_host.py "{{ out }}"

# Show the registered Gerbil implementation selected for the host platform.
[group('build')]
toolchain:
    {{ bazel }} build --toolchain_resolution_debug={{ gerbil_toolchain_type }} {{ gerbil_compile }}

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
