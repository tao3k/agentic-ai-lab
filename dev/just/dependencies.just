# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Install the dependency revisions declared by gerbil.pkg.
[group('dependency')]
deps:
    {{ gerbil_darwin_env }} gerbil deps --install
    {{ gerbil_darwin_env }} gerbil clean

# Rebuild one installed source without fetching or changing its dependencies.
[group('dependency')]
build-dependency package:
    {{ gerbil_darwin_env }} gerbil env gxpkg build "{{ package }}"

# Verify that dependency resolution is represented by the tracked lock.
[group('dependency')]
lock-check:
    {{ bazel }} mod deps --lockfile_mode=error

# Refresh this host's native Bazel lock; CI merges Linux and Darwin evaluations.
[group('dependency')]
bazel-update:
    {{ bazel }} mod deps --lockfile_mode=update

# Change a direct Gerbil dependency once. Its owning gerbil.pkg is authoritative; the
# source archive digest and both platform lock projections are derived.
[group('dependency')]
pin-gerbil-dependency package revision:
    python3 packages/automation/gerbil_dependency_pin.py pin "{{ package }}" "{{ revision }}"
    {{ bazel }} mod deps --lockfile_mode=update
    python3 packages/automation/gerbil_dependency_pin.py sync-lock
    python3 packages/automation/gerbil_dependency_pin.py check

# Normalize MODULE.bazel declarations while explicitly updating the lock.
[group('dependency')]
mod-tidy:
    {{ bazel }} mod tidy --lockfile_mode=update

# Let Gerbil update and build the dependencies declared by Core. Prefetch only
# supplies immutable objects; it deliberately never moves an existing checkout.
# The official update owns both checkout/tag coherence and incremental builds.
[group('dependency')]
bootstrap-native-poo:
    python3 packages/automation/gerbil_dependency_pin.py prepare-native --manifest core/gerbil.pkg --package-root "{{ agentic_ai_lab_gerbil_path }}/pkg"
    cd "{{ justfile_directory() }}/core" && GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap={{ gerbil_test_max_heap }},debug={{ gerbil_test_debug }}" /usr/bin/time -p {{ gerbil_darwin_env }} timeout --verbose --signal=TERM --kill-after=5s 600s gerbil interactive ../packages/automation/native-dependencies.ss

# Optional ASP policy probes belong to the development package, not the library.
[group('dependency')]
deps-dev:
    python3 packages/automation/gerbil_dependency_pin.py prepare-native --manifest dev/gerbil.pkg --package-root "{{ agentic_ai_lab_gerbil_path }}/pkg"
    cd "{{ justfile_directory() }}/dev" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} gerbil env gxi ../packages/automation/native-dependencies.ss

# Compile installed test dependencies against the Gerbil-selected shared library.
# Dependency acquisition belongs to deps-dev, as production acquisition belongs
# to deps. Running tests must not reinstall POO into a second library prefix.
[group('build')]
build-testing: build-library
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} gxpkg build github.com/tao3k/asp-gerbil-scheme

# Reuse the maintained, hash-locked qualification inputs; retain a GC root.
[group('dependency')]
prepare-test-inputs:
    nix-build --out-link "{{ agentic_ai_lab_gerbil_path }}/test-inputs" t/fixtures/opentofu/ci.nix

# Init owns module qualification discovery/support; the official compiler
# prepares the signed publication before the existing native Harness runs.
[group('build')]
build-module-qualification: build-library
    cd "{{ justfile_directory() }}/t/qualification/native-module-support" && GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap={{ gerbil_test_max_heap }},debug={{ gerbil_test_debug }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} build

# These existing recovery tests execute native workers rather than mocks.
[group('build')]
build-test-workers:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} just --justfile t/qualification/nix/Justfile build
