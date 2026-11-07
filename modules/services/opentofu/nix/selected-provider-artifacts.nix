# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Values are passed as argv strings by the Core build tool, never shell code.
{ catalog, selection, collector }:
let
  pkgs = import <nixpkgs> {};
  demand = builtins.fromJSON (builtins.readFile (builtins.toPath selection));
  current = import ../../../nix/source-inputs.nix;
in
assert current demand.source-inputs; pkgs.callPackage (builtins.toPath collector) {
  schemas = import (builtins.toPath catalog) { inherit pkgs; };
  selection = demand;
}
