# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
{ pkgs ? import <nixpkgs> { }
, nixComponents ? pkgs.nixVersions."nixComponents_${pkgs.lib.replaceStrings [ "." ] [ "_" ] (pkgs.lib.versions.majorMinor pkgs.nix.version)}"
}:
let
  inherit (pkgs) lib;
  inherit (nixComponents) nix-everything nix-expr nix-expr-c nix-fetchers-c nix-flake-c nix-store-c nix-util-c;
in
assert lib.versionAtLeast nix-expr-c.version "2.34";
{
  qualification = pkgs.symlinkJoin {
    name = "agentic-ai-lab-nix-c-api-tools";
    paths = [ nix-everything ] ++ map lib.getDev [
      nix-expr-c
      nix-fetchers-c
      nix-flake-c
      nix-store-c
      nix-util-c
    ];
  };

  derivation-worker = pkgs.stdenv.mkDerivation {
    pname = "agentic-ai-lab-nix-derivation-worker";
    inherit (nix-expr) version;
    src = ./derivation-worker.cc;
    dontUnpack = true;
    strictDeps = true;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ nix-expr nix-expr-c pkgs.boost ];
    buildPhase = ''
      runHook preBuild
      $CXX -O2 -DLAB_NIX_VERSION='"${nix-expr.version}"' \
        $(pkg-config --cflags nix-expr-c nix-expr) -x c++ "$src" \
        $(pkg-config --libs nix-expr-c nix-expr) -o nix-derivation-worker
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 nix-derivation-worker "$out/bin/nix-derivation-worker"
      ln -s "${lib.getExe' nix-everything "nix-instantiate"}" "$out/bin/nix-instantiate"
      runHook postInstall
    '';
  };
}
