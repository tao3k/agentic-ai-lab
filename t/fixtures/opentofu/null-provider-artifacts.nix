# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Produce the actual locked Null Schema/Provider/engine output once. The
# execution test then selects this immutable derivation rather than repeatedly
# evaluating the entire nixpkgs producer at each freshness boundary.
let
  pkgs = import <nixpkgs> {};
  schemas = import ./family-schemas.nix { inherit pkgs; };
in pkgs.callPackage ../../../modules/services/opentofu/nix/provider-artifacts.nix {
  inherit schemas;
  selection.providers = [ "null" ];
}
