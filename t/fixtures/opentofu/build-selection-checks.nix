# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs }:
let
  collect = schemas: providers:
    pkgs.callPackage ../../../modules/services/opentofu/nix/provider-artifacts.nix {
      inherit schemas; selection = { inherit providers; };
    };
  catalog = import ./family-schemas.nix { inherit pkgs; };
  poisoned = collect {
    inherit (catalog) aws;
    awscc = throw "unselected awscc package evaluated";
    null = throw "unselected Null package evaluated";
  } [ "aws" ];
  valid = collect catalog [ "aws" ];
  evaluates = value: (builtins.tryEval (builtins.deepSeq value.drvPath true)).success;
in {
  unselectedPackagesNotEvaluated = poisoned.drvPath == valid.drvPath;
  missingPackageRejected = !(evaluates (collect catalog [ "unknown" ]));
  duplicateSelectionRejected = !(evaluates (collect catalog [ "aws" "aws" ]));
  unsafeSelectionRejected = !(evaluates (collect catalog [ "../aws" ]));
  emptySelectionEvaluates = evaluates (collect catalog []);
}
