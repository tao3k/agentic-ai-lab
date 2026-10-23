# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs }:
let
  release = name: version: hash:
    import ./hashicorp-package.nix { inherit pkgs name version hash; };
  schema = provider: pkgs.callPackage
    ../../../modules/services/opentofu/nix/provider-schema.nix { inherit provider; };
in {
  aws = schema (import ./aws-5.100.0/package.nix { inherit pkgs; });
  awscc = schema (release "awscc" "1.77.0"
    { aarch64-darwin = "sha256:b9bc0e947d8e04f166c736bec9a06ea07841c95fe7d1caea753bdc5131af3a74"; x86_64-linux = "sha256:fec465402acc4b9df5471dd854e8c6cf9eb36971affa665506caf2f95c8f8e9c"; });
  "null" = schema (release "null" "3.2.4"
    { aarch64-darwin = "sha256:c43723e8cc65bcdf5e0c92581dcbbdcbdcf18b8d2037406a5f2033b1e22de442"; x86_64-linux = "sha256:9d32ac3619cfc93eb3c4f423492a8e0f79db05fec58e449dee9b2d5873d5f69f"; });
}
