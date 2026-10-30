# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Serialized Core observations: validate before building any package dependency.
inputs:
builtins.all (input:
  let path = builtins.toPath input.path;
  in if input.present then
    if builtins.pathExists path &&
       builtins.hashString "sha256" (builtins.readFile path) == input.sha256
    then true
    else throw "stale Nix source input: ${input.path}"
  else if !(builtins.pathExists path) then true
    else throw "stale negative Nix source input: ${input.path}"
) inputs
