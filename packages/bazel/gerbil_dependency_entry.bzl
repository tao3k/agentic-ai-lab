# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Generate a native PackageSpec bootstrap for a dependency's demanded APIs.

Source ownership still comes from the upstream build-script label. The shared
Gerbil project provider stages external inputs in .gerbil-bazel/external/; this
adapter derives that location from the label, never a machine checkout path.
"""

def _project_path(path):
    if path.startswith("../"):
        return ".gerbil-bazel/external/" + path[3:]
    if path.startswith(".gerbil-bazel/"):
        fail("reserved source staging path: {}".format(path))
    return path

def _impl(ctx):
    marker = _project_path(ctx.file.source_build.short_path)
    entries = ctx.attr.entry_modules
    if not entries or len(depset(entries).to_list()) != len(entries):
        fail("dependency entry modules must be nonempty and unique")
    for entry in entries:
        if not entry.endswith(".ss") or entry.startswith("/") or ".." in entry.split("/"):
            fail("expected package-local Scheme entry: {}".format(entry))
        for character in entry.elems():
            if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-":
                fail("unsupported entry path character: {}".format(entry))
    script = ctx.actions.declare_file(ctx.label.name + ".ss")
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = script,
        substitutions = {
            "@SOURCE_ROOT@": "/".join(marker.split("/")[:-1]),
            "@BACKTRACK@": "../" * (len(_project_path(script.short_path).split("/")) - 1),
            "@ENTRIES@": " ".join([json.encode(entry) for entry in entries]),
        },
    )
    return [DefaultInfo(files = depset([script]))]

gerbil_dependency_entry = rule(
    implementation = _impl,
    attrs = {
        "source_build": attr.label(mandatory = True, allow_single_file = [".ss"]),
        "entry_modules": attr.string_list(mandatory = True),
        "_template": attr.label(default = Label(":dependency-entry.ss.in"), allow_single_file = True),
    },
)
