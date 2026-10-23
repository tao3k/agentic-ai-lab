# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Historical real-provider control. Production callers select their own package.
{ pkgs
, version ? "5.100.0"
, hash ? {
    aarch64-darwin = "sha256:bb64e8aff37becab373a1a0cc1080990785304141af42ed6aa3dd4913b000421";
    x86_64-linux = "sha256:1589a2266af699cbd5d80737a0fe02e54ec9cf2ca54e7e00ac51c7359056f274";
  }
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  platform = { aarch64-darwin = "darwin_arm64"; x86_64-linux = "linux_amd64"; }.${system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "terraform-provider-aws";
  inherit version;
  # The native fixed-output fetcher reports transfer counters to Nix's activity
  # stream. A curl builder's carriage-return display is not liveness evidence.
  # URL, expected content hash and archive name retain the same fixed output.
  # stdenv.fetchurlBoot can itself be replaced by a later curl bootstrap stage.
  # Use Nix's shipped fixed-output builder rather than inferring from its name.
  src = import <nix/fetchurl.nix> {
    system = pkgs.stdenv.hostPlatform.system;
    url = "https://releases.hashicorp.com/terraform-provider-aws/${version}/terraform-provider-aws_${version}_${platform}.zip";
    hash = hash.${system};
  };
  nativeBuildInputs = [ pkgs.unzip ];
  unpackPhase = ''unzip "$src"'';
  installPhase = ''
    directory="$out/libexec/terraform-providers/registry.terraform.io/hashicorp/aws/${version}/${platform}"
    mkdir -p "$directory"
    install -m755 terraform-provider-aws_v${version}_x5 "$directory/terraform-provider-aws_v${version}_x5"
  '';
  passthru.provider-source-address = "registry.terraform.io/hashicorp/aws";
}
