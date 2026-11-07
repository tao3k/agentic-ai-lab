# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Reuse the existing pinned provider fixtures and the maintained Schema builder.
{ pkgs }:
let
  versions = import ./versioned-schemas.nix { inherit pkgs; };
  families = import ./family-schemas.nix { inherit pkgs; };
in pkgs.linkFarm "admission-provider-inputs" [
  { name = "parent"; path = versions.parent; }
  { name = "child"; path = versions.child; }
  { name = "null"; path = families."null"; }
  { name = "engine"; path = families."null".engine; }
  { name = "aws-engine"; path = versions.child.engine; }
]
