# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Hermetic Bundle v1 images generated from downstream Agentic AI Lab Scheme."""

load(
    "@gerbil_bazel//gerbil:defs.bzl",
    "GERBIL_TOOLCHAIN_TYPE",
    "GerbilProjectInfo",
    "resolved_gerbil_toolchain",
)

AgenticAILabBundleV1Info = provider(
    doc = "Declared Bundle v1 descriptor and arena generated from Scheme.",
    fields = {
        "arena": "Bundle v1 immutable arena image.",
        "descriptor": "Bundle v1 descriptor image.",
        "project_receipt": "Receipt for the compiled Agentic AI Lab Scheme project.",
        "source": "Downstream Scheme composition entrypoint.",
    },
)

def _agentic_ai_lab_bundle_v1_impl(ctx):
    project = ctx.attr.project[GerbilProjectInfo]
    toolchain = resolved_gerbil_toolchain(ctx)
    descriptor = ctx.outputs.descriptor_out
    arena = ctx.outputs.arena_out
    dependency_roots = project.dependency_roots.to_list()
    gerbil_path = project.project_root.path + "/.gerbil"
    load_path = [gerbil_path + "/lib"]
    load_path.extend([
        root.path + "/.gerbil/lib"
        for root in dependency_roots
    ])
    load_path.extend([
        ctx.file.src.dirname,
        toolchain.dependency_library_root.dirname,
    ])
    load_path.extend([
        source.dirname
        for source in ctx.files.srcs
    ])

    arguments = ctx.actions.args()
    arguments.add("env")
    arguments.add("GERBIL_PATH=" + gerbil_path)
    arguments.add("GERBIL_LOADPATH=" + ":".join(load_path))
    arguments.add("AGENTIC_AI_LAB_BUNDLE_V1_ID=" + ctx.attr.bundle_id)
    arguments.add("AGENTIC_AI_LAB_BUNDLE_V1_EPOCH=" + str(ctx.attr.bundle_epoch))
    arguments.add("YUANXU_BUNDLE_V1_DESCRIPTOR_OUT=" + descriptor.path)
    arguments.add("YUANXU_BUNDLE_V1_ARENA_OUT=" + arena.path)
    arguments.add(toolchain.gxi.executable.path)
    arguments.add(ctx.file.src.path)

    environment = dict(toolchain.environment)
    environment.update({
        "GERBIL_BAZEL_NATIVE_ABI": toolchain.native_abi_fingerprint,
        "AGENTIC_AI_LAB_GERBIL_NATIVE_ABI": toolchain.native_abi_fingerprint,
    })
    ctx.actions.run(
        arguments = [arguments],
        env = environment,
        executable = toolchain.native_scheme_env,
        inputs = depset(
            direct = [
                ctx.file.src,
            ] + ctx.files.srcs + [
                project.project_root,
                project.receipt,
                toolchain.dependency_library_root,
                toolchain.native_abi_fingerprint_file,
            ],
            transitive = [
                project.dependency_roots,
                toolchain.dependency_libraries,
                toolchain.runfiles,
            ],
        ),
        mnemonic = "AgenticAILabBundleV1",
        outputs = [descriptor, arena],
        progress_message = "Lowering Agentic AI Lab Scheme Bundle v1 %{label}",
        tools = [toolchain.gxi, toolchain.native_scheme_env],
    )

    return [
        DefaultInfo(files = depset([descriptor, arena])),
        AgenticAILabBundleV1Info(
            arena = arena,
            descriptor = descriptor,
            project_receipt = project.receipt,
            source = ctx.file.src,
        ),
        OutputGroupInfo(
            arena = depset([arena]),
            descriptor = depset([descriptor]),
        ),
    ]

agentic_ai_lab_bundle_v1 = rule(
    implementation = _agentic_ai_lab_bundle_v1_impl,
    attrs = {
        "arena_out": attr.output(mandatory = True),
        "bundle_epoch": attr.int(default = 1),
        "bundle_id": attr.string(mandatory = True),
        "descriptor_out": attr.output(mandatory = True),
        "project": attr.label(
            default = Label("//:compile"),
            providers = [GerbilProjectInfo],
        ),
        "src": attr.label(
            allow_single_file = [".ss"],
            mandatory = True,
        ),
        "srcs": attr.label_list(
            allow_files = [".ss", ".scm", ".ssi", ".inc"],
        ),
    },
    toolchains = [GERBIL_TOOLCHAIN_TYPE],
)
