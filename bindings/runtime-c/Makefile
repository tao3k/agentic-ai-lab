# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

OUT ?= ../../.gerbil/runtime-c
CPPFLAGS += -Iinclude -Ibundle-v1/include
CFLAGS += -std=c11 -Wall -Wextra -Werror -pedantic -fPIC
CXXFLAGS += -std=c++17 -Wall -Wextra -Werror -pedantic
AR ?= ar
ifeq ($(shell uname -s),Darwin)
EXT := dylib
SHARED := -dynamiclib
else
EXT := so
SHARED := -shared
endif

RUNTIME := $(OUT)/runtime_v0.o $(OUT)/proof_case_v1.o
BUNDLE := $(OUT)/bundle_v1.o
RUNTIME_TESTS := runtime_v0_harness runtime_v0_batch_harness runtime_v0_installed_consumer proof_case_v1_harness proof_case_v1_installed_consumer scheme_contract_v1_header_harness

.PHONY: all runtime bundle test-runtime test-bundle sanitizers leaks clean
all: runtime bundle
runtime: $(OUT)/libagentic_ai_lab_runtime_v0.$(EXT) $(OUT)/libagentic_ai_lab_runtime_v0.a
bundle: $(OUT)/libagentic_ai_lab_bundle_v1.$(EXT) $(OUT)/libagentic_ai_lab_bundle_v1.a

$(OUT):
	mkdir -p "$@"
$(OUT)/%.o: src/%.c | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@
$(BUNDLE): bundle-v1/src/bundle_v1.c | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@
$(OUT)/libagentic_ai_lab_runtime_v0.$(EXT): $(RUNTIME)
	$(CC) $(SHARED) $^ $(LDFLAGS) -o $@
$(OUT)/libagentic_ai_lab_runtime_v0.a: $(RUNTIME)
	$(AR) rcs $@ $^
$(OUT)/libagentic_ai_lab_bundle_v1.$(EXT): $(BUNDLE)
	$(CC) $(SHARED) $^ $(LDFLAGS) -o $@
$(OUT)/libagentic_ai_lab_bundle_v1.a: $(BUNDLE)
	$(AR) rcs $@ $^
$(OUT)/%: tests/%.c $(RUNTIME) | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(RUNTIME) $(LDFLAGS) -o $@
$(OUT)/proof_case_v1_benchmark: benchmarks/proof_case_v1_benchmark.c $(RUNTIME)
	$(CC) $(CPPFLAGS) $(CFLAGS) -O3 $< $(RUNTIME) $(LDFLAGS) -o $@
$(OUT)/runtime_v0_batch_benchmark: benchmarks/runtime_v0_batch_benchmark.c $(RUNTIME)
	$(CC) $(CPPFLAGS) $(CFLAGS) -O3 $< $(RUNTIME) $(LDFLAGS) -o $@
$(OUT)/bundle_v1_harness: bundle-v1/tests/bundle_v1_harness.c $(BUNDLE)
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(BUNDLE) $(LDFLAGS) -o $@
$(OUT)/bundle_v1_scheme_image_harness: bundle-v1/tests/bundle_v1_scheme_image_harness.c $(BUNDLE)
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(BUNDLE) $(LDFLAGS) -o $@
$(OUT)/bundle_v1_cpp_consumer: bundle-v1/tests/bundle_v1_cpp_consumer.cc $(BUNDLE)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< $(BUNDLE) $(LDFLAGS) -o $@

test-runtime: all $(addprefix $(OUT)/,$(RUNTIME_TESTS)) $(OUT)/runtime_v0_vector_harness $(OUT)/proof_case_v1_benchmark $(OUT)/runtime_v0_batch_benchmark
	$(foreach test,$(RUNTIME_TESTS),$(OUT)/$(test) && ) true
	$(OUT)/runtime_v0_vector_harness tests/vectors/runtime_v0_event_1.txt
	$(OUT)/proof_case_v1_benchmark 5
	$(OUT)/runtime_v0_batch_benchmark 20
test-bundle: $(OUT)/bundle_v1_harness $(OUT)/bundle_v1_cpp_consumer $(OUT)/bundle_v1_scheme_image_harness
	$(OUT)/bundle_v1_harness
	$(OUT)/bundle_v1_cpp_consumer
sanitizers:
	$(MAKE) OUT="$(OUT)/asan" CFLAGS="$(CFLAGS) -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="$(LDFLAGS) -fsanitize=address" test-runtime test-bundle
	$(MAKE) OUT="$(OUT)/ubsan" CFLAGS="$(CFLAGS) -fsanitize=undefined -fno-omit-frame-pointer" LDFLAGS="$(LDFLAGS) -fsanitize=undefined" test-runtime test-bundle
leaks: $(OUT)/runtime_v0_harness $(OUT)/runtime_v0_batch_harness
ifeq ($(shell uname -s),Darwin)
	leaks -atExit -- $(OUT)/runtime_v0_harness
	leaks -atExit -- $(OUT)/runtime_v0_batch_harness
else
	valgrind --error-exitcode=1 --leak-check=full $(OUT)/runtime_v0_harness
	valgrind --error-exitcode=1 --leak-check=full $(OUT)/runtime_v0_batch_harness
endif
clean:
	rm -rf "$(OUT)"

-include $(RUNTIME:.o=.d) $(BUNDLE:.o=.d)
