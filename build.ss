#!/usr/bin/env -S timeout --signal=TERM --kill-after=5s 900s gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Build-only watchdog for the complete cold library. Runtime test profiles
;;; retain their independent heap, total-duration and idle-duration gates.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-build-spec))

;; Native package clones acquire the declared Core gitlink before source lowering.
(def retained-spec
  (begin
    ;; Bootstrap a missing checkout only. An existing Core may contain an
    ;; intentional revision or local work and must not be reset by a build.
    (unless (file-exists? (path-expand "core/gerbil.pkg" (path-directory (this-source-file))))
      (run-process
        (list "git" "-C" (path-directory (this-source-file))
              "submodule" "update" "--init" "--depth" "1" "--" "core")
        stdin-redirection: #f stdout-redirection: #f))
    ;; Compatibility consumers may start in dev/. Retained library paths
    ;; are always resolved against this product entry, never the caller's cwd.
    (parameterize ((current-directory (path-directory (this-source-file))))
      (agentic-ai-lab-build-spec))))

;; The selected init owns source lowering; the SDK owns Make and dispatch.
(def modules-spec (.get agentic-ai-lab.init.exports std-make-spec))
(defbuild-script (modules-spec retained-spec))
