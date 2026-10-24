# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Reuse an actual store derivation through Nix's built-in derivation importer.
# This fixture supports only the Null request and retains the selected source
# observations. It never substitutes a fabricated Provider or command result.
{ derivation, selection }:
let
  demand = builtins.fromJSON (builtins.readFile (builtins.toPath selection));
  current = import ../../../modules/nix/source-inputs.nix;
in
assert demand.providers == [ "null" ];
assert current demand.source-inputs;
import (builtins.toPath derivation)
