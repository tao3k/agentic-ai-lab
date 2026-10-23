# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Resolve and build the canonical Scheme project through build.ss.
[group('build')]
build:
    just build-core
    just build-library

# Compile the full product library against the selected Core installation.
# The default build above still requires Core to build successfully first.
[group('build')]
build-library:
    GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil build

# Compile the pinned local Core, replacing any transitive bootstrap artifacts.
# Cleaning is confined to the Core package; dependency source checkouts stay intact.
[group('build')]
build-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil clean
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil build

# Clean only native Gerbil package build artifacts.
[group('build')]
clean:
    gerbil clean

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
build-semantic-native output:
    python3 bindings/runtime-c/tools/build-semantic.py --output "{{ output }}"

# Compile the bounded acyclic support kernel before native runtime qualification.
[group('build')]
build-temporal-support:
    gxc -:max-heap=1G,debug=q -V -O modules/temporal-causality/revisions/types.ss modules/temporal-causality/revisions/objects.ss modules/temporal-causality/revisions/funs.ss modules/temporal-causality/revisions/interface.ss modules/temporal-causality/truth-maintenance/support/types.ss modules/temporal-causality/truth-maintenance/support/objects.ss modules/temporal-causality/truth-maintenance/support/funs.ss modules/temporal-causality/truth-maintenance/support/policy.ss modules/temporal-causality/truth-maintenance/support/interface.ss modules/temporal-causality/truth-maintenance/interface.ss

# Named original ASCENT positive-proof adapter and host policy boundary.
[group('build')]
build-temporal-evaluator:
    gxc -:max-heap=1G,debug=q -V -O modules/temporal-causality/truth-maintenance/support/policy-host.ss modules/temporal-causality/evaluator/positive-proof.ss modules/temporal-causality/evaluator/fact.ss modules/temporal-causality/evaluator/binding.ss modules/temporal-causality/evaluator/rule.ss modules/temporal-causality/evaluator/derivation.ss modules/temporal-causality/evaluator/proof-host.ss modules/temporal-causality/evaluator/interface.ss

# Build the installed upstream gxtest source without whole-program elimination:
# dynamic eval requires runtime globals that cannot be inferred statically.
[group('build')]
build-gerbil-test-tool output:
    #!/usr/bin/env bash
    set -euo pipefail
    tool_home="$(gerbil env bash -c 'printf %s "$GERBIL_HOME"')"
    mkdir -p "{{ output }}/source" "{{ output }}/lib"
    cp "$tool_home/src/tools/gxtest.ss" "{{ output }}/source/gxtest.ss"
    cp "$tool_home/src/tools/build-aot.ss" "{{ output }}/source/build-aot.ss"
    cp "$tool_home/src/tools/env.ss" "{{ output }}/source/env.ss"
    patch --batch -d "{{ output }}/source" -p1 < tools/ci/patches/gerbil-gxtest-runtime-init.patch
    printf '(package: gerbil/tools)\n' > "{{ output }}/source/gerbil.pkg"
    export GERBIL_LOADPATH="{{ output }}/lib${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}"
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 180s gerbil compile -s -d "{{ output }}/lib" "{{ output }}/source/env.ss"
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 180s gerbil compile -exe -s -d "{{ output }}/lib" -o "{{ output }}/gxtest" "{{ output }}/source/gxtest.ss"
