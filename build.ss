#!/usr/bin/env -S timeout --verbose --signal=TERM --kill-after=5s 180s gxi
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
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-build-spec))

;; Runtime package clones acquire the declared Core gitlink before source lowering.
(def (ensure-core-source!)
  ;; An existing Core may contain local work and must not be reset by a build.
  (unless (file-exists? (path-expand "core/gerbil.pkg" (path-directory (this-source-file))))
    (run-process
      (list "git" "-C" (path-directory (this-source-file))
            "submodule" "update" "--init" "--depth" "1" "--" "core")
      stdin-redirection: #f stdout-redirection: #f)))

;; The selected init owns source lowering; Yuanxu owns Make and dispatch.
(def modules-spec (.get agentic-ai-lab.init.exports std-make-spec))
(defbuild-script
  (begin
    (ensure-core-source!)
    (modules-spec
      (if (current-build-module-roots)
        '()
        (parameterize ((current-directory (path-directory (this-source-file))))
          (agentic-ai-lab-build-spec))))))
