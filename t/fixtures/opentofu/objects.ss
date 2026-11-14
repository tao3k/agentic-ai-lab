;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (rename-in (only-in :tao3k/yuanxu/ops/interface Ops) (Ops OpsScope))
        (only-in :tao3k/yuanxu/profile-composition/selection-syntax use-module)
        (only-in :tao3k/yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :tao3k/yuanxu/module-system/source/reader module-publication-reader)
        (only-in :tao3k/yuanxu/module-system/source/directory module-directory-context))
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
                           "--justfile" "t/fixtures/nix/Justfile"
                           "test" "t/yanxu/modules/services/opentofu/selected-graph-test.ss")
                timeout: 145 check-status: #f)
              FlakeSource:
              (.o (:: @ Script)
                command: '("/usr/bin/time" "-p" "just"
                           "--justfile" "t/fixtures/nix/Justfile"
                           "test" "t/yanxu/modules/nix/flake-source-test.ss")
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
(def (configured-opentofu-modules init configure (configuration-owner #f))
  (def reader (module-publication-reader))
  (def (read-publication source)
    (let* ((published (.call reader read source))
           (baseline (.get published core)))
      (case (.get published identity)
        ((services/opentofu)
         (.cc published 'core
           (.o (:: @ baseline)
             exports: (configure (.get baseline exports))
             package-build: (lambda () (.cc (.call baseline package-build)
                                         'module (configure (.get baseline exports)))))))
        ((app/infrastructure)
         (if (not configuration-owner) published
           (.cc published 'core
             (.o (:: @ baseline)
               projections:
               (let* ((upstream (.call reader read
                                 (.call context locate 'services/opentofu)))
                      (build (.call (.get upstream core) package-build)))
                 (list (.cc build 'module (configure (.get build module)))))))))
        (else published))))
  (def context (module-directory-context init read-publication))
  (yuanxu-load-modules
    (.cc context
      'import-owners (.get reader import-owners) 'publication-inputs (.get reader inputs)
      'publication-preparation (.get reader preparation)
      'current? (lambda (generation)
                  (.call reader admit-current)
                  (.call context current? generation)))))
