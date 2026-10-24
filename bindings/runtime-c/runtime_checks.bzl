# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Runtime-C checks that need a small Bazel-native test launcher."""

load(
    "@gerbil_bazel//gerbil:defs.bzl",
    "GERBIL_TOOLCHAIN_TYPE",
    "resolved_gerbil_toolchain",
)

def _runtime_leak_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    binary_paths = [binary[DefaultInfo].files_to_run.executable.short_path for binary in ctx.attr.binaries]
    quoted_paths = " ".join(["\"$runfiles/%s\"" % path for path in binary_paths])
    ctx.actions.write(
        output = executable,
        content = """#!/bin/sh
set -eu
runfiles="${TEST_SRCDIR}/${TEST_WORKSPACE}"
case "$(uname -s)" in
  Darwin)
    for binary in %s; do
      leaks -atExit -- "$binary"
    done
    ;;
  *)
    if ! command -v valgrind >/dev/null 2>&1; then
      echo "no supported leak checker available" >&2
      exit 77
    fi
    for binary in %s; do
      valgrind --error-exitcode=1 --leak-check=full "$binary"
    done
    ;;
esac
""" % (quoted_paths, quoted_paths),
        is_executable = True,
    )

    runfiles = ctx.runfiles()
    for binary in ctx.attr.binaries:
        runfiles = runfiles.merge(binary[DefaultInfo].default_runfiles)
        runfiles = runfiles.merge(binary[DefaultInfo].data_runfiles)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

runtime_leak_test = rule(
    implementation = _runtime_leak_test_impl,
    test = True,
    attrs = {
        "binaries": attr.label_list(
            cfg = "target",
            mandatory = True,
        ),
    },
)

def _runtime_contract_parity_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    pairs = [
        (ctx.file.generated_header, ctx.file.checked_header),
        (ctx.file.generated_vector, ctx.file.checked_vector),
        (ctx.file.generated_event_vector, ctx.file.checked_event_vector),
    ]
    commands = []
    for generated, checked in pairs:
        commands.append(
            "diff -u \"$runfiles/%s\" \"$runfiles/%s\"" % (
                checked.short_path,
                generated.short_path,
            ),
        )
    ctx.actions.write(
        output = executable,
        content = "#!/bin/sh\nset -eu\nrunfiles=\"${TEST_SRCDIR}/${TEST_WORKSPACE}\"\n%s\n" % "\n".join(commands),
        is_executable = True,
    )
    files = []
    for generated, checked in pairs:
        files.extend([generated, checked])
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = files),
    )]

runtime_contract_parity_test = rule(
    implementation = _runtime_contract_parity_test_impl,
    test = True,
    attrs = {
        "checked_event_vector": attr.label(allow_single_file = True, mandatory = True),
        "checked_header": attr.label(allow_single_file = True, mandatory = True),
        "checked_vector": attr.label(allow_single_file = True, mandatory = True),
        "generated_event_vector": attr.label(allow_single_file = True, mandatory = True),
        "generated_header": attr.label(allow_single_file = True, mandatory = True),
        "generated_vector": attr.label(allow_single_file = True, mandatory = True),
    },
)

def _runtime_gerbil_script_test_impl(ctx):
    toolchain = resolved_gerbil_toolchain(ctx)
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    argument_files = []
    for target in ctx.attr.arguments:
        files = target[DefaultInfo].files.to_list()
        if len(files) != 1:
            fail(
                "runtime_gerbil_script_test argument %s must provide exactly one file, got %d" %
                (target.label, len(files)),
            )
        argument_files.append(files[0])

    command_arguments = [
        "\"$runfiles/%s\"" % toolchain.gxi.executable.short_path,
    ] + ["\"$runfiles/%s\"" % file.short_path for file in argument_files]
    ctx.actions.write(
        output = executable,
        content = """#!/bin/sh
set -eu
runfiles="${TEST_SRCDIR}/${TEST_WORKSPACE}"
cd "$runfiles"
exec "$runfiles/%s" %s
""" % (
            ctx.file.script.short_path,
            " ".join(command_arguments),
        ),
        is_executable = True,
    )

    transitive_files = [target[DefaultInfo].files for target in ctx.attr.data]
    transitive_files.extend([target[DefaultInfo].files for target in ctx.attr.arguments])
    runfiles = ctx.runfiles(
        files = [ctx.file.script],
        transitive_files = depset(transitive = transitive_files + [toolchain.runfiles]),
    )
    for target in ctx.attr.arguments + ctx.attr.data:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)
        runfiles = runfiles.merge(target[DefaultInfo].data_runfiles)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

runtime_gerbil_script_test = rule(
    implementation = _runtime_gerbil_script_test_impl,
    test = True,
    attrs = {
        "arguments": attr.label_list(allow_files = True),
        "data": attr.label_list(allow_files = True),
        "script": attr.label(allow_single_file = True, mandatory = True),
    },
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)

def _shell_quote(value):
    return "'{}'".format(value.replace("'", "'\"'\"'"))

def _runtime_gerbil_benchmark_test_impl(ctx):
    toolchain = resolved_gerbil_toolchain(ctx)
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    library = ctx.attr.library[DefaultInfo].files.to_list()[0]
    ctx.actions.write(
        output = executable,
        content = """#!/bin/sh
set -eu
runfiles="${TEST_SRCDIR}/${TEST_WORKSPACE}"
source="$runfiles/%s"
header="$runfiles/%s"
contract_header="$runfiles/%s"
library="$runfiles/%s"
library_dir="$(dirname "$library")"
gxc="$runfiles/%s"
gxi="$runfiles/%s"
native_env="$runfiles/%s"
gerbil_cc=%s
gerbil_as=%s
gerbil_ld=%s
output_root="$TEST_TMPDIR/gerbil"
mkdir -p "$output_root/lib"
"$native_env" env -u CPATH -u C_INCLUDE_PATH -u LIBRARY_PATH \
  GERBIL_CC="$gerbil_cc" \
  GERBIL_AS="$gerbil_as" \
  GERBIL_LD="$gerbil_ld" \
  "$gxc" -O -d "$output_root/lib" \
  -cc-options "-I$(dirname "$(dirname "$header")") -I$(dirname "$(dirname "$contract_header")")" \
  -ld-options "-L$library_dir -lruntime_c_shared -Wl,-rpath,$library_dir" \
  "$source"
env -u CPATH -u C_INCLUDE_PATH -u LIBRARY_PATH \
  DYLD_LIBRARY_PATH="$library_dir" \
  LD_LIBRARY_PATH="$library_dir" \
  GERBIL_PATH="$output_root" \
  "$gxi" -e '(begin (import :agentic-ai-lab/bindings/runtime-c/benchmarks/runtime-v0-gerbil-ffi-benchmark) (main))'
""" % (
            ctx.file.source.short_path,
            ctx.file.header.short_path,
            ctx.file.contract_header.short_path,
            library.short_path,
            toolchain.gxc.executable.short_path,
            toolchain.gxi.executable.short_path,
            toolchain.native_scheme_env.executable.short_path,
            _shell_quote(toolchain.gerbil_cc),
            _shell_quote(toolchain.gerbil_as),
            _shell_quote(toolchain.gerbil_ld),
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [
        ctx.file.contract_header,
        ctx.file.header,
        ctx.file.package_file,
        ctx.file.source,
        library,
    ])
    runfiles = runfiles.merge(ctx.runfiles(transitive_files = toolchain.runfiles))
    return [DefaultInfo(executable = executable, runfiles = runfiles)]

runtime_gerbil_benchmark_test = rule(
    implementation = _runtime_gerbil_benchmark_test_impl,
    test = True,
    attrs = {
        "contract_header": attr.label(allow_single_file = True, mandatory = True),
        "header": attr.label(allow_single_file = True, mandatory = True),
        "library": attr.label(mandatory = True),
        "package_file": attr.label(allow_single_file = True, mandatory = True),
        "source": attr.label(allow_single_file = [".ss"], mandatory = True),
    },
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)
