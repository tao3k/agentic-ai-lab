#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in :yuanxu/module-system/building/products current-build-module-roots)
        (only-in "./build-modules.ss" agentic-ai-lab.build-modules.exports))
(export main)

;; Explicit source builds can use the declared Core gitlink.
(def (ensure-core-source!)
  ;; An existing Core may contain local work and must not be reset by a build.
  (unless (file-exists? (path-expand "core/gerbil.pkg" (path-directory (this-source-file))))
    (run-process
      (list "git" "-C" (path-directory (this-source-file))
            "submodule" "update" "--init" "--depth" "1" "--" "core")
      stdin-redirection: #f stdout-redirection: #f)))

;; Installation supplies no Module roots and no package library targets.
(def modules-spec (.get agentic-ai-lab.build-modules.exports std-make-spec))
(defbuild-script
  (let (roots (or (current-build-module-roots) '()))
    (parameterize ((current-build-module-roots roots))
      (when (pair? roots) (ensure-core-source!))
      (modules-spec '()))))
