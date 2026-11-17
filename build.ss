#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .call .get .o)
        (only-in :std/source this-source-file)
        (only-in :std/build-script defbuild-script)
        (only-in :std/make make)
        (only-in :gerbil/tools/gxpkg pkg-root-dir)
        (only-in :tao3k/yuanxu/module-system/building/build-script defmodule-build-script)
        (only-in :tao3k/yuanxu/module-system/building/build-projection yuanxu-project-source-spec)
        (only-in :tao3k/yuanxu/module-system/building/products current-build-module-roots)
        (only-in :tao3k/yuanxu/module-system/building/source-package
                 call-with-build-input-path call-with-build-source-fallbacks)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

;; Ask the dependency's init for the modules Lab imports. Make keeps the
;; dependency's source directory and package prefix for those targets.
(def (prepare-yuanxu-modules _options)
  (def installed (path-expand "github.com/tao3k/gebril-yuanxu" (pkg-root-dir)))
  (def source
    (path-normalize
      (if (file-exists? (path-expand "init.ss" installed))
        installed
        (path-expand "core" (path-directory (this-source-file))))))
  (call-with-build-source-fallbacks (list source)
    (lambda ()
      (def projection
        (parameterize ((current-build-module-roots '(json-schema funflow)))
          (yuanxu-project-source-spec (path-expand "init.ss" source) '()
            source (path-expand "build.ss" source))))
      (.call projection .with-compiler-inputs
        (lambda ()
          (call-with-build-input-path #f
            (lambda () (make (.get projection std-make-spec) srcdir: source))
            make-source: source))))))

;; Downstream packages import this public library independently of the
;; selected Module graph. Retain it through the init-owned Make projection.
(def LabBuild
  (.o (:: @ tao3k/agentic-ai-lab.init.exports)
      build: (.call tao3k/agentic-ai-lab.init.exports .yuanxu-init
               '("modules/module-authoring/interface"))))

(defmodule-build-script
  (defbuild-script (.get LabBuild std-make-spec))
  (.o .prepare: prepare-yuanxu-modules))
