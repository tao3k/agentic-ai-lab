#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .call)
        (only-in :std/build-script defbuild-script)
        (only-in :std/make make make-clean)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

;; Default package installation compiles ONLY a minimal 1-2 module baseline.
;; This repository scales to 1,000-10,000+ modules: NEVER expand build-modules
;; into a full-repo inventory and NEVER add ad hoc native-library side-channels
;; (e.g. package-library-spec / with-public-library-spec) here.
;; Downstream consumers declare and compile the exact modules they need on
;; demand through their own `yuanxu!` init declaration; `just test` verifies
;; all modules independently of default package compilation.
(def build-modules
  '(modules/ai-agentic-context modules/temporal-causality))

(def (build-options flags)
  (foldr (lambda (flag options)
           (match flag
             ("--release" (cons* build-release: #t options))
             ("--optimized" (cons* build-optimized: #t options))
             ("--debug" (cons* debug: #t options))
             (else (error "Unexpected build option" flag))))
         '() flags))

(def (compile flags)
  (def options (build-options flags))
  ;; The admitted source view preserves each package's compiler identities.
  (.call tao3k/agentic-ai-lab.init.exports .compile-selection build-modules '()
    (lambda (targets root) (apply make targets srcdir: root options))
    package-roots?: #t))

(def (main . arguments)
  (match arguments
    ([] (compile '()))
    (["compile" . flags] (compile flags))
    (["clean"]
     (.call tao3k/agentic-ai-lab.init.exports .clean-selection build-modules '()
       (lambda (targets root) (make-clean targets srcdir: root))
       package-roots?: #t))
    (else
     (let ()
       (defbuild-script (.call tao3k/agentic-ai-lab.init.exports .make-spec-for build-modules
                          package-roots?: #t))
       (apply main arguments)))))
