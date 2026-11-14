#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Lab declaration owns adapter selection. Gerbil follows the tool's
;;; ordinary imports for its transitive dependencies.
(import (only-in :std/make make pkg-config-libs)
        (only-in :std/source this-source-file)
        (only-in :clan/poo/object .get .call .o)
        (only-in :gerbil/expander core-import-module)
        (only-in :tao3k/yuanxu/module-system/building/products
                 build-output-directory current-build-source-directory)
        (only-in :tao3k/yuanxu/module-system/building/artifacts call-with-static-compiler-inputs)
        (only-in :tao3k/yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in :tao3k/yuanxu/module-system/building/source-package call-with-build-input-path)
        (only-in :tao3k/yuanxu/module-system/source/static-inputs module-static-compiler-inputs)
        (rename-in (only-in "./init.ss" agentic-ai-lab-nix-qualification.init.exports)
                   (agentic-ai-lab-nix-qualification.init.exports adapter-exports)))

(def root (path-directory (this-source-file)))
(def output (build-output-directory))
(def tool-target
  (list exe: "tools" bin: "build-publication-tools"
        "-ld-options" (pkg-config-libs "libcrypto" "libssl")))

(def (build targets (with-inputs (lambda (_projection action) (action))))
  (call-with-build-input-path output
    (lambda ()
      (def projection (.call adapter-exports .project-build targets))
      (.call projection .with-compiler-inputs
        (lambda ()
          (with-inputs projection
            (lambda ()
              (make (.get projection spec)
                srcdir: (or (current-build-source-directory) root)
                libdir: output bindir: (path-expand "bin" (gerbil-path))))))))))

;; The worker imports public libraries that consume selected adapter products.
(build '())
(build '("programs" "approved-producer" "worker" "store-producer"))
(build (list tool-target)
  (lambda (projection action)
    (def contexts '())
    (for-each-build-module (core-import-module (path-expand "tools.ss" root))
      (lambda (context) (set! contexts (cons context contexts))))
    (call-with-static-compiler-inputs
      (.o static-inputs:
          (module-static-compiler-inputs (reverse contexts) (.get projection compiler-identities)))
      action)))
(displayln "NIX-ADAPTER-BUILD-OK")
