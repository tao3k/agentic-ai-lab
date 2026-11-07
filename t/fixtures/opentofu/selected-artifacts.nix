# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs, selectionFile }:
import ./family-artifacts.nix {
  inherit pkgs;
  selection = builtins.fromJSON (builtins.readFile selectionFile);
}
