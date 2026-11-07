;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (rename-in (only-in :yuanxu/ops/interface Ops) (Ops OpsScope))
        (only-in :yuanxu/profile-composition/selection-syntax use-module)
        (only-in :yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :yuanxu/module-system/source/reader module-publication-reader)
        (only-in :yuanxu/module-system/source/directory module-directory-context))
(export Ops configured-opentofu-modules)
;; One admitted scope from the built-in Core library; no operation starts here.
(def Ops
  (use-module OpsScope as ops
    (with-slots (Script) (.get ops prototypes)
      (.o (:: @ ops)
          tests:
          (.o SelectedGraph:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just"
                           "--justfile" "t/qualification/nix/Justfile"
                           "test" "t/opentofu-selected-graph-test.ss")
                timeout: 145 check-status: #f)
              FlakeSource:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just"
                           "--justfile" "t/qualification/nix/Justfile"
                           "test" "t/nix-flake-source-test.ss")
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

;; Upstream package configuration is a runtime derivation of the one real
;; publication. The existing source-context hook retains its reader observations.
;; No alternative declaration, copied module implementation or runtime Loader.
(def (configured-opentofu-modules init configure (standalone-projection #f))
  (def reader (module-publication-reader))
  (def (read-publication source)
    (let* ((published (.call reader read source))
           (baseline (.get published core)))
      (if (not (eq? (.get published identity) 'services/opentofu)) published
        (.cc published 'core
          (.o (:: @ baseline)
            projections:
            (let (projections (.get baseline projections))
              (if (not standalone-projection) projections
                (let* ((configured-scope (configure (.get baseline scope)))
                       (build (.get baseline configuration-build)))
                  (append projections
                    (list (.cc build 'module configured-scope
                                 'configuration-projection
                                 (lambda (_)
                                   (standalone-projection (.get configured-scope config)))))))))
            link: (lambda (dependencies) (configure (.call baseline link dependencies)))
            configuration-build:
            (let (build (.get baseline configuration-build))
              (.cc build 'module (configure (.get build module)))))))))
  (def context (module-directory-context init read-publication))
  (yuanxu-load-modules
    (.cc context
      'publication-inputs (.get reader inputs)
      'publication-preparation (.get reader preparation)
      'current? (lambda (generation)
                  (.call reader admit-current)
                  (.call context current? generation)))))
