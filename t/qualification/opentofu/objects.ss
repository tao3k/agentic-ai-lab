;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (rename-in (only-in :yuanxu/ops/interface Ops) (Ops OpsScope))
        (only-in :yuanxu/profile-composition/selection-syntax use-module))
(export Ops)
;; One admitted scope from the built-in Core library; no operation starts here.
(def Ops
  (use-module OpsScope as ops
    (with-slots (Script) (.get ops prototypes)
      (.o (:: @ ops)
          tests:
          (.o SelectedGraph:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just" "test-opentofu-selected-graph")
                timeout: 145 check-status: #f)
              SelectedFlake:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just" "test-opentofu-selected-flake")
                timeout: 145 check-status: #f)
              FlakeSource:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just" "test-nix-flake")
                timeout: 145 check-status: #f))
          tools:
          (.o PackageSet:
              (.o (:: @ Script) command: '("nix-instantiate" "--find-file" "nixpkgs") timeout: 30)
              NixVersion:
              (.o (:: @ Script) command: '("nix" "--version") timeout: 5)
              HostLoad:
              (.o (:: @ Script) command: '("uptime") timeout: 5)
              CPUCount:
              (.o (:: @ Script) command: '("getconf" "_NPROCESSORS_ONLN") timeout: 5))))))
