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
        (only-in :std/build-script defbuild-script)
        (only-in :yuanxu/module-system/building/interface call-with-init-build-spec)
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

;; The package installation selects no business Modules. An explicit request
;; narrows the same init-owned projection before the native Make entry runs.
(def (split-build-modules args)
  (let scan ((rest args) (native '()) (roots #f))
    (cond
     ((null? rest) (values (reverse native) roots))
     ((string=? (car rest) "--modules")
      (unless (and (not roots) (pair? args) (member (car args) '("compile" "spec")))
        (error "--modules may appear once after compile or spec"))
      (let names ((remaining (cdr rest)) (selected '()))
        (if (or (null? remaining) (string-prefix? "--" (car remaining)))
          (begin
            (when (null? selected) (error "--modules requires one or more module IDs"))
            (scan remaining native (reverse selected)))
          (let (id (string->symbol (car remaining)))
            (when (or (string=? (car remaining) "") (memq id selected))
              (error "empty or duplicate module ID" (car remaining)))
            (names (cdr remaining) (cons id selected))))))
     (else (scan (cdr rest) (cons (car rest) native) roots)))))

(def (main . args)
  (defvalues (native-args selected) (split-build-modules args))
  (def roots (or selected '()))
  (parameterize ((current-build-module-roots roots))
    (when (pair? roots) (ensure-core-source!))
    (call-with-init-build-spec
      (lambda () (modules-spec '()))
      (lambda (spec arguments (package-prefix #f))
        (when package-prefix
          (error "Lab selected build has an unexpected package prefix" package-prefix))
        (let ()
          (defbuild-script spec)
          (apply main arguments)))
      native-args #f (this-source-file))))
