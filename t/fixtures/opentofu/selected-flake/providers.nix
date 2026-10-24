# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs }:
let
  schema = provider: pkgs.callPackage ./lib/provider-schema.nix { inherit provider; };
in {
  aws = schema (import ./aws-package.nix { inherit pkgs; });
  "null" = schema (import ./hashicorp-package.nix {
    inherit pkgs;
    name = "null";
    version = "3.2.4";
    hash = { aarch64-darwin = "sha256:c43723e8cc65bcdf5e0c92581dcbbdcbdcf18b8d2037406a5f2033b1e22de442"; x86_64-linux = "sha256:9d32ac3619cfc93eb3c4f423492a8e0f79db05fec58e449dee9b2d5873d5f69f"; };
  });
  # A lazy catalog branch: even evaluating it is a qualification failure.
  awscc = throw "unselected awscc must not be evaluated or built";
}
