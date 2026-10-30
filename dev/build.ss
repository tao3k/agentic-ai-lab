#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The existing development package owns optional native test preparation.
;;; Production gerbil build remains independent of ASP development tooling.
;;; The native support producer and consumer must use the same installed-library
;;; priority. The Just entry supplies the product source as a fallback only.
(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "../init.ss" agentic-ai-lab.init.exports)
        (only-in "./performance-tests.ss" agentic-ai-lab-performance-test-demand))
;; This is the Root init's source projection, compiled through the official
;; package command. The standard srcdir setting retains its original Make root.
(def demand (agentic-ai-lab-performance-test-demand agentic-ai-lab.init.exports))
(displayln "test-preparation owner=development source-root=" (.get demand source-root)
           " file-count=" (length (.get demand spec))
           " first-file=" (car (.get demand spec)))
(force-output)
(def product-root (path-expand ".." (path-directory (this-source-file))))

(def (build-support args)
  (defbuild-script
    ((.get demand std-make-spec))
    prefix: "agentic-ai-lab"
    srcdir: product-root)
  (apply main args))

(def (main . args)
  (build-support args)
  (when (or (null? args) (equal? (car args) "compile"))
    ;; Keep each init-owned declaration in a fresh native expander epoch.
    ;; Support publication and executable linking must observe the same
    ;; installed interfaces as an independent consumer. This is the existing
    ;; official preparation sequence, now owned by development rather than
    ;; every downstream production build.
    (parameterize ((current-directory product-root))
      (def (declaration name)
        (append (list "gerbil" "interactive" (path-expand name product-root)) args))
      ;; The existing Nix Just entry retains its original aggregate 240-second
      ;; phase fence inside this package's independent 900-second build fence.
      ;; It consumes standard init-owned declarations, never a private runner.
      (for-each
        (lambda (command)
          (run-process command stdin-redirection: #f stdout-redirection: #f))
        (list (declaration "qualification-build.ss")
              (list "just" "--justfile"
                    (path-expand "t/qualification/nix/Justfile" product-root) "build")
              (declaration "context-build.ss"))))))
