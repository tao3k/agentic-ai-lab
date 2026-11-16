#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :tao3k/yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'tao3k/agentic-ai-lab))

(import (only-in :std/source this-source-file)
        (only-in :std/build-script defbuild-script)
        (only-in :clan/poo/object .get .call)
        (only-in :tao3k/yuanxu/module-system/building/products current-build-source-directory)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))
(export main)

;; Publish the same init-selected closure consumed by native clients. The
;; existing init projection owns source routing, Make targets and clean.
;; The ordinary authoring facade is also a public native library product.
(def source-root (path-directory (this-source-file)))
(def (main . arguments)
  (def projection (.call tao3k/agentic-ai-lab.init.exports .project-build '("init" "modules/module-authoring/interface")))
  (def spec (.get projection spec))
  (def (dispatch)
    (def (this-source-file)
      (path-expand "build.ss" (or (current-build-source-directory) source-root)))
    (defbuild-script spec)
    (apply main arguments))
  (match arguments
    (["clean"] (.call projection .with-clean-outputs dispatch))
    (["spec"] (dispatch))
    (["meta"] (dispatch))
    (else (.call projection .with-compiler-inputs dispatch))))
