# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Executable environments derived from a declared Gerbil project build."""

load(
    "@gerbil_bazel//gerbil:defs.bzl",
    "GERBIL_TOOLCHAIN_TYPE",
    "GerbilProjectInfo",
    "resolved_gerbil_toolchain",
)

GerbilProjectEnvironmentInfo = provider(
    doc = "A command environment backed by one compiled Gerbil project.",
    fields = {
        "project": "Gerbil project provider that owns the compiled environment.",
        "receipt": "JSON declaration receipt for the executable environment.",
    },
)

def _runfile_key(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return "{}/{}".format(ctx.workspace_name, file.short_path)

def _runfiles_init():
    return """rlocation() {
  local key=$1
  local runfiles_dir=${RUNFILES_DIR:-${BASH_SOURCE[0]}.runfiles}
  local runfiles_manifest=${RUNFILES_MANIFEST_FILE:-${BASH_SOURCE[0]}.runfiles_manifest}
  if [[ -e $runfiles_dir/$key ]]; then
    printf '%s\\n' "$runfiles_dir/$key"
    return
  fi
  if [[ -f $runfiles_manifest ]]; then
    awk -v key="$key" '$1 == key {sub($1 " ", ""); print; exit}' "$runfiles_manifest"
    return
  fi
  printf 'cannot resolve runfile: %s\\n' "$key" >&2
  exit 1
}
"""

def _gerbil_project_environment_impl(ctx):
    project = ctx.attr.project[GerbilProjectInfo]
    toolchain = resolved_gerbil_toolchain(ctx)
    runner_target = ctx.attr._runner[DefaultInfo]
    runner = runner_target.files_to_run
    executable = ctx.actions.declare_file(ctx.label.name)
    receipt = ctx.actions.declare_file(ctx.label.name + ".receipt.json")
    project_dependency_roots = project.dependency_roots.to_list()

    declaration = {
        "schema": "agentic-ai-lab.gerbil-project-environment-declaration.v1",
        "label": str(ctx.label),
        "project": str(ctx.attr.project.label),
        "nativeAbi": toolchain.native_abi_fingerprint,
        "workingDirectory": ctx.attr.working_directory,
        "loadPathOrder": [
            "project",
            "project-dependencies",
            "toolchain-dependencies",
        ],
    }
    ctx.actions.write(
        output = receipt,
        content = json.encode_indent(declaration, indent = "  ") + "\n",
    )

    dependency_arguments = "\n".join([
        "arguments+=(--project-dependency-root \"$(rlocation {})\")".format(
            repr(_runfile_key(ctx, root)),
        )
        for root in project_dependency_roots
    ])
    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail
{runfiles_init}
workspace=${{BUILD_WORKSPACE_DIRECTORY:?run this target with bazel run}}
runner=$(rlocation {runner_key})
gxi=$(rlocation {gxi_key})
native_scheme_env=$(rlocation {native_scheme_env_key})
project_root=$(rlocation {project_root_key})
project_receipt=$(rlocation {project_receipt_key})
dependency_root_marker=$(rlocation {dependency_root_key})
declaration_receipt=$(rlocation {receipt_key})
arguments=(
  --gxi "$gxi"
  --native-scheme-env "$native_scheme_env"
  --project-root "$project_root"
  --project-receipt "$project_receipt"
  --dependency-root-marker "$dependency_root_marker"
  --workspace "$workspace"
  --working-directory {working_directory}
  --declaration-receipt "$declaration_receipt"
)
{dependency_arguments}
exec "$runner" "${{arguments[@]}}" -- "$@"
""".format(
            dependency_arguments = dependency_arguments,
            dependency_root_key = repr(_runfile_key(ctx, toolchain.dependency_library_root)),
            gxi_key = repr(_runfile_key(ctx, toolchain.gxi.executable)),
            native_scheme_env_key = repr(_runfile_key(ctx, toolchain.native_scheme_env.executable)),
            project_receipt_key = repr(_runfile_key(ctx, project.receipt)),
            project_root_key = repr(_runfile_key(ctx, project.project_root)),
            receipt_key = repr(_runfile_key(ctx, receipt)),
            runfiles_init = _runfiles_init(),
            runner_key = repr(_runfile_key(ctx, runner.executable)),
            working_directory = repr(ctx.attr.working_directory),
        ),
    )

    runfiles = ctx.runfiles(
        files = [
            executable,
            receipt,
            project.project_root,
            project.receipt,
            runner.executable,
            toolchain.dependency_library_root,
            toolchain.gxi.executable,
            toolchain.native_scheme_env.executable,
        ],
        transitive_files = depset(transitive = [
            project.dependency_roots,
            runner_target.default_runfiles.files,
            toolchain.runfiles,
        ]),
    )
    return [
        DefaultInfo(
            executable = executable,
            files = depset([executable, receipt]),
            runfiles = runfiles,
        ),
        GerbilProjectEnvironmentInfo(
            project = project,
            receipt = receipt,
        ),
        OutputGroupInfo(receipt = depset([receipt])),
    ]

gerbil_project_environment = rule(
    implementation = _gerbil_project_environment_impl,
    attrs = {
        "project": attr.label(
            mandatory = True,
            providers = [GerbilProjectInfo],
        ),
        "working_directory": attr.string(),
        "_runner": attr.label(
            cfg = "exec",
            default = Label("//packages/bazel:gerbil_project_environment_tool"),
            executable = True,
        ),
    },
    executable = True,
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)
