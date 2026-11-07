# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Test package graph. Production callers supply their own locked package inputs.
{ pkgs }:
let
  package = args: import ./aws-5.100.0/package.nix ({ inherit pkgs; } // args);
  schema = provider: pkgs.callPackage
    ../../../modules/services/opentofu/nix/provider-schema.nix { inherit provider; };
in {
  parent = schema (package {
    version = "5.99.0";
    hash = { aarch64-darwin = "sha256:d77fc7e17730eb40cde656e67fc206e9d7ca2a346d9e1819e6f3bd71289207e2"; x86_64-linux = "sha256:ac8e1fb974569f0c5fdc09f5991fb8b0e79ccf4086799bf64715317f3a27a7fd"; };
  });
  child = schema (package { });
}
