# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Developer driver of the published D2 Module. Heap and timeout precede imports.
[group('design')]
d2-export output="dev/d2/output" source="dev/d2/drive.ss":
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} "{{ source }}" "{{ output }}"

# One current Context snapshot, not an orchestration loop or stage machine.
[group('design')]
d2-author revision="r1":
    bun dev/d2/session-render.ts --verify
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} dev/d2/author.ss "{{ revision }}"

# Consume the official SysML SDK capture through the public Module scope.
[group('design')]
d2-design:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} dev/d2/design.ss

# Same generic adapter for any POO case and SDK capture; no per-design recipe.
[group('design')]
d2-reuse mode="evaluate":
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} dev/d2/reuse.ss "{{ mode }}"

# Focused official Gerbil test launcher. The same heap fence applies before
# imports; this entry does not depend on Core's private progress adapter.
[group('test')]
test-d2:
    GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap={{ gerbil_test_max_heap }},debug={{ gerbil_test_debug }}" GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/yanxu/modules/d2/module-test.ss t/context-window-ascent-test.ss t/d2-reader-review-test.ss t/d2-explanation-test.ss t/d2-authoring-test.ss t/d2-image-reading-test.ss t/d2-scene-test.ss t/d2-teaching-test.ss

# The rule-only gate retains the same limits and does not claim Module closure.
[group('test')]
test-d2-rules:
    GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap={{ gerbil_test_max_heap }},debug={{ gerbil_test_debug }}" GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/d2-reader-rules-test.ss
