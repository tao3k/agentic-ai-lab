# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# One locked source supplies both the package path and its unpacked NAR identity.
let
  source = {
    url = "https://github.com/NixOS/nixpkgs/archive/9eac87a12312b8f60dd52e1c6e1a265f6fc7f5fc.tar.gz";
    sha256 = "sha256-d2xfDjnfRuf/xYGdu9VVRHiav/2w5hDL/5cw2TuVAXw=";
  };
in {
  outPath = builtins.fetchTarball source;
  narHash = source.sha256;
}
