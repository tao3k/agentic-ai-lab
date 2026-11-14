# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs, selection ? { providers = [ "aws" "awscc" "null" ]; } }:
pkgs.callPackage ../../../modules/services/opentofu/nix/provider-artifacts.nix {
  inherit selection;
  schemas = import ./family-schemas.nix { inherit pkgs; };
}
