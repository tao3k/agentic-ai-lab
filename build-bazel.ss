;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/source this-source-file)
        (only-in :std/make make)
        (only-in :clan/poo/object .call .get)
        (only-in :tao3k/yuanxu/module-system/building/products
                 build-output-directory current-build-source-directory)
        (only-in :tao3k/yuanxu/module-system/building/source-package
                 call-with-build-source-fallbacks)
        (only-in "./init-bazel.ss" tao3k/agentic-ai-lab.init-bazel.exports))

(export main)

(def (main (operation "compile"))
  (def entries
    (cond
     ((equal? operation "compile")
      '("modules/workflow/profiles/funflow-library"
        "modules/workflow/scenario/runtime-funflow"))
     ((equal? operation "qualify")
      '("t/qualification/context-temporal/interface"))
     (else (error "unknown Lab build operation" operation))))
  (def root (path-directory (this-source-file)))
  (def output (build-output-directory))
  (call-with-build-source-fallbacks (list (path-expand "core" root))
    (lambda ()
      (def projection
        (.call tao3k/agentic-ai-lab.init-bazel.exports .project-build entries))
      (.call projection .with-compiler-inputs
        (lambda ()
          (make (.get projection spec)
            srcdir: (or (current-build-source-directory) root) libdir: output))))))
