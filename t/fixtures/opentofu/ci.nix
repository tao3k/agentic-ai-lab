# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# Real qualification inputs. These are not production provider selections.
let
  source = import ../nixpkgs.nix;
  pkgs = import source.outPath { };
  versions = import ./versioned-schemas.nix { inherit pkgs; };
  inputs = {
  families = import ./family-artifacts.nix { inherit pkgs; };
  awsOnly = import ./family-artifacts.nix {
    inherit pkgs; selection.providers = [ "aws" ];
  };
  awsNull = import ./family-artifacts.nix {
    inherit pkgs; selection.providers = [ "aws" "null" ];
  };
  inherit (versions) parent child;
  # Byte-authentication control for the recorded historical Darwin binary.
  # It is streamed for hashing, never executed on Linux.
  binary = pkgs.runCommand "aws-5.100.0-historical-binary" {
    nativeBuildInputs = [ pkgs.unzip ];
    archive = pkgs.fetchurl {
      url = "https://releases.hashicorp.com/terraform-provider-aws/5.100.0/terraform-provider-aws_5.100.0_darwin_arm64.zip";
      hash = "sha256:bb64e8aff37becab373a1a0cc1080990785304141af42ed6aa3dd4913b000421";
    };
  } ''
    mkdir -p "$out"
    unzip -p "$archive" terraform-provider-aws_v5.100.0_x5 > "$out/provider"
  '';
  tools = pkgs.writeText "agentic-ai-lab-nix-test-tools.json" (builtins.toJSON {
    shell = toString pkgs.bash;
    tools = toString pkgs.coreutils;
    system = pkgs.stdenv.hostPlatform.system;
    nixpkgs = toString source.outPath;
    nixpkgsHash = source.narHash;
  });
  };
in pkgs.linkFarm "yuanxu-provider-qualification"
  (pkgs.lib.mapAttrsToList (name: path: { inherit name path; }) inputs)
