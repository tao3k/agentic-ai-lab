# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# The caller selects a finite package graph. No scan of the global provider set.
{ lib, linkFarm, schemas, selection }:
let
  names = selection.providers;
  selected = lib.genAttrs names (name:
    schemas.${name} or (throw "OpenTofu build-required: Provider '${name}' has no locked package"));
in
assert builtins.isList names && lib.all builtins.isString names;
assert lib.length (lib.unique names) == lib.length names;
assert lib.all (name: builtins.match "[A-Za-z0-9_]+" name != null)
  names;
linkFarm "opentofu-artifacts" (lib.mapAttrsToList (name: path: {
  inherit name path;
}) selected)
