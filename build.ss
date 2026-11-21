#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .call)
        (only-in :std/source this-source-file)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/build-script defbuild-script)
        (only-in :std/make make-clean)
        (only-in :tao3k/yuanxu/module-system/building/source-closure package-library-spec)
        (only-in :tao3k/yuanxu/module-system/building/source-package
                 call-with-build-input-path package-library-prefix)
        (only-in :tao3k/yuanxu/module-system/building/products build-output-directory)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

(def build-modules
  '(modules/ai-agentic-context modules/temporal-causality modules/nix modules/gitops
    YuanxuModules/funflow YuanxuModules/json-schema))

;; Public native libraries are not Module declarations. Gerbil's real import
;; graph supplies their private dependencies; this is not a source-file inventory.
(def (with-public-library-spec action)
  (def root (path-directory (this-source-file)))
  (call-with-build-input-path (build-output-directory)
    (lambda ()
      (action
        (package-library-spec root 'tao3k/agentic-ai-lab
          '("modules/governance/interface.ss"
            "modules/session/objects-core.ss"
            "modules/loop-engine/control/governor.ss"
            "modules/loop-engine/control/strategy.ss"
            "modules/loop-engine/control/descriptor.ss"
            "modules/authorization/providers/cedar/objects.ss")) root))
    source-roots: (list root) make-source: root))

(def (run-build targets root args)
  (def (this-source-file) (path-expand "build.ss" root))
  (defbuild-script targets libdir: (build-output-directory))
  (apply main args))

(def (compile flags)
  (def args (cons "compile" flags))
  ;; Selected Core Modules supply the public libraries' runtime prerequisites.
  (.call tao3k/agentic-ai-lab.init.exports .compile-selection build-modules '()
    (lambda (targets root) (run-build targets root args))
    package-roots?: #t)
  (with-public-library-spec
    (lambda (targets root) (run-build targets root args))))

(def (main . arguments)
  (match arguments
    ([] (compile '()))
    (["compile" . flags] (compile flags))
    (["clean"]
     (with-public-library-spec
       (lambda (targets root)
         (make-clean targets srcdir: root)
         (.call tao3k/agentic-ai-lab.init.exports .clean-selection build-modules '()
           (lambda (targets root) (make-clean targets srcdir: root))
           package-roots?: #t))))
    (else
     (let ()
       (def public-targets
         (with-public-library-spec
           (lambda (targets root)
             (map (cut string-append (package-library-prefix root) <>) targets))))
       (defbuild-script
         (delete-duplicates/hash
           (append (.call tao3k/agentic-ai-lab.init.exports .make-spec-for build-modules
                     package-roots?: #t) public-targets)
           key: (lambda (target) (if (string? target) target (cadr target)))
           from-end?: #t))
       (apply main arguments)))))
