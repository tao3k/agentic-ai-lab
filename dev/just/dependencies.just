# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Install Lab dependencies, then restore the vendored Core dependency revisions.
[group('dependency')]
deps:
    {{ lab_build_env }} gerbil env gxi packages/automation/runtime-dependencies.ss
    cd "{{ justfile_directory() }}/core" && {{ lab_build_env }} gerbil env gxi ../packages/automation/runtime-dependencies.ss
    {{ lab_build_env }} gerbil clean

# Rebuild one installed source without fetching or changing its dependencies.
[group('dependency')]
build-dependency package:
    {{ gerbil_darwin_env }} gerbil env gxpkg build "{{ package }}"

# Optional ASP source-admission probes belong to the development package.
[group('dependency')]
deps-dev:
    cd "{{ justfile_directory() }}/dev" && GERBIL_PATH="{{ agentic_ai_lab_dev_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_build_library_path }}" {{ gerbil_darwin_env }} gerbil env gxi ../packages/automation/runtime-dependencies.ss

# Compile the installed development probe dependency against the shared library.
# Dependency acquisition belongs to deps-dev, as production acquisition belongs
# to deps. The development package owns dependencies, not a second product build.
# test-root separately requires build-library in the production prefix.
[group('build')]
build-testing:
    GERBIL_PATH="{{ agentic_ai_lab_dev_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_build_library_path }}" {{ gerbil_darwin_env }} gxpkg build github.com/tao3k/asp-gerbil-scheme
    just build-test-support

# Yuanxu owns the import closure; explicit files only narrow the same projection.
[group('build')]
[positional-arguments]
build-test-support *paths:
    GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap=4G,live-ratio=50,debug={{ gerbil_test_debug }}" GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} {{ gerbil_test_timeout }} 600s gerbil -:max-heap=4G,live-ratio=50,debug={{ gerbil_test_debug }} interactive t/harness/build-test-support.ss "$@"

# Reuse the maintained, hash-locked qualification inputs; retain a GC root.
[group('dependency')]
prepare-test-inputs:
    nix-build --out-link "{{ agentic_ai_lab_gerbil_path }}/test-inputs" t/fixtures/opentofu/ci.nix

# Recovery workers read the runtime store and build their library products separately.
[group('build')]
build-test-workers:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_gerbil_path }}/lib" {{ gerbil_darwin_env }} just --justfile t/fixtures/nix/Justfile build "{{ agentic_ai_lab_gerbil_path }}/nix-workers/lib"
