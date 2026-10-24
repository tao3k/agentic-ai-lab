# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Agentic AI Lab artifact projections from a shared Gerbil project build."""

load(
    "@gerbil_bazel//gerbil:defs.bzl",
    "GERBIL_TOOLCHAIN_TYPE",
    "GerbilProjectInfo",
    "resolved_gerbil_toolchain",
)

GerbilProjectionInfo = provider(
    doc = "One Agentic AI Lab projection artifact derived from a Gerbil project.",
    fields = {
        "artifact": "Packaged no-Gerbil projection artifact.",
        "project": "Shared Gerbil project provider used by the action.",
    },
)

def _gerbil_project_projection_impl(ctx):
    toolchain = resolved_gerbil_toolchain(ctx)
    project = ctx.attr.project[GerbilProjectInfo]
    project_dependency_roots = project.dependency_roots.to_list()
    artifact = ctx.actions.declare_file(ctx.attr.output_name)

    arguments = ctx.actions.args()
    arguments.add("--gxi")
    arguments.add(toolchain.gxi.executable.path)
    arguments.add("--compiled-root")
    arguments.add(project.project_root.path + "/.gerbil")
    arguments.add("--dependency-root-marker")
    arguments.add(toolchain.dependency_library_root.path)
    for dependency_root in project_dependency_roots:
        arguments.add("--project-dependency-root")
        arguments.add(dependency_root.path)
    arguments.add("--projection-source")
    arguments.add(ctx.file.projection_source.path)
    arguments.add("--source")
    arguments.add(ctx.file.source.path)
    arguments.add("--output")
    arguments.add(artifact.path)

    environment = dict(toolchain.environment)
    environment.update({
        "GERBIL_BAZEL_NATIVE_ABI": toolchain.native_abi_fingerprint,
        "AGENTIC_AI_LAB_GERBIL_NATIVE_ABI": toolchain.native_abi_fingerprint,
    })
    ctx.actions.run(
        arguments = [arguments],
        executable = ctx.attr._exporter[DefaultInfo].files_to_run,
        env = environment,
        inputs = depset(
            direct = [
                ctx.file.projection_source,
                ctx.file.source,
                project.project_root,
                toolchain.dependency_library_root,
                toolchain.native_abi_fingerprint_file,
            ],
            transitive = [project.dependency_roots, toolchain.dependency_libraries],
        ),
        mnemonic = "GerbilProjectProjection",
        outputs = [artifact],
        progress_message = "Projecting canonical Gerbil module %{label}",
        tools = [toolchain.gxi],
    )

    return [
        DefaultInfo(files = depset([artifact])),
        GerbilProjectionInfo(
            artifact = artifact,
            project = project,
        ),
    ]

gerbil_project_projection = rule(
    implementation = _gerbil_project_projection_impl,
    attrs = {
        "output_name": attr.string(mandatory = True),
        "project": attr.label(
            mandatory = True,
            providers = [GerbilProjectInfo],
        ),
        "projection_source": attr.label(
            allow_single_file = [".ss"],
            mandatory = True,
        ),
        "source": attr.label(
            allow_single_file = [".ss"],
            mandatory = True,
        ),
        "_exporter": attr.label(
            cfg = "exec",
            default = Label("//packages/bazel:scheme_projection_artifact_tool"),
            executable = True,
        ),
    },
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)

def _gerbil_project_contract_projection_impl(ctx):
    toolchain = resolved_gerbil_toolchain(ctx)
    project = ctx.attr.project[GerbilProjectInfo]
    project_dependency_roots = project.dependency_roots.to_list()
    artifact = ctx.actions.declare_file(ctx.attr.output_name)

    arguments = ctx.actions.args()
    arguments.add(ctx.file.projector.path)
    arguments.add(artifact.path)

    environment = dict(toolchain.environment)
    environment.update({
        "GERBIL_PATH": project.project_root.path + "/.gerbil",
        "GERBIL_LOADPATH": ":".join(
            [project.project_root.path + "/.gerbil/lib"] +
            [
                root.path + "/.gerbil/lib"
                for root in project_dependency_roots
            ] +
            [toolchain.dependency_library_root.path],
        ),
        "AGENTIC_AI_LAB_GERBIL_NATIVE_ABI": toolchain.native_abi_fingerprint,
    })
    ctx.actions.run(
        arguments = [arguments],
        executable = toolchain.gxi,
        env = environment,
        inputs = depset(
            direct = [
                ctx.file.projector,
                project.project_root,
                toolchain.dependency_library_root,
                toolchain.native_abi_fingerprint_file,
            ],
            transitive = [
                project.dependency_roots,
                toolchain.dependency_libraries,
                toolchain.runfiles,
            ],
        ),
        mnemonic = "GerbilProjectContractProjection",
        outputs = [artifact],
        progress_message = "Projecting POO contract %{label}",
        tools = [toolchain.gxi],
    )
    return [DefaultInfo(files = depset([artifact]))]

gerbil_project_contract_projection = rule(
    implementation = _gerbil_project_contract_projection_impl,
    attrs = {
        "output_name": attr.string(mandatory = True),
        "project": attr.label(
            mandatory = True,
            providers = [GerbilProjectInfo],
        ),
        "projector": attr.label(
            allow_single_file = [".ss"],
            mandatory = True,
        ),
    },
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)
