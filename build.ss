#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .call)
        (only-in :std/build-script defbuild-script)
        (only-in :std/make make-clean)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

(def build-modules
  '(modules/ai-agentic-context modules/temporal-causality modules/nix))

(defvalues (main)
  (let ()
    ;; The Temporal Module contributes its declared FFI targets to native Make.
    (defbuild-script (.call tao3k/agentic-ai-lab.init.exports .make-spec-for build-modules))
    (lambda arguments
      (match arguments
        (["clean"]
         (.call tao3k/agentic-ai-lab.init.exports .clean-selection build-modules '()
           (lambda (targets root) (make-clean targets srcdir: root))))
        (else (apply main arguments))))))
