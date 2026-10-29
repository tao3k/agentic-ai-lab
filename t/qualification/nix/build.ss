#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native Nix qualification preparation uses the existing init Test demand.
;;; Standard Make owns closure discovery, source admission and both packages.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  ;; Reuse the package source gateway before native import discovery. The
  ;; adapter package must work before any Root library has been installed.
  (register-module-build-source!
    (path-expand "../../.." (path-directory (this-source-file))) 'agentic-ai-lab))
(import (only-in :clan/poo/object .get .call)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports)
        (only-in "../../../build-spec.ss"
          agentic-ai-lab-nix-producer-demand agentic-ai-lab-nix-program-consumer)
        (only-in "./programs.ss" nix-publication-programs)
        (only-in :yuanxu/module-system/building/artifacts retain-test-support-subset!))
(def root (path-expand "../../.." (path-directory (this-source-file))))
(def demand (agentic-ai-lab-nix-producer-demand agentic-ai-lab.init.exports root))
(def (build-producers args)
  (defbuild-script
    ((.get demand std-make-spec))
    prefix: "agentic-ai-lab"
    srcdir: root)
  (apply main args))
(def (main . args)
  (def compile? (or (null? args) (equal? (car args) "compile")))
  (def (worker)
    (parameterize ((current-directory root))
      (run-process
        (append (list "gerbil" "interactive"
                  (path-expand "nix-worker-build.ss" root)) args)
        stdin-redirection: #f stdout-redirection: #f)))
  (def (producer)
    (build-producers args)
    (when compile?
      (let (consumer
            (agentic-ai-lab-nix-program-consumer agentic-ai-lab.init.exports demand
              (path-expand "t/qualification/nix/tools.ss" root)))
        (retain-test-support-subset! (.get demand build) (.get consumer build))
        (displayln "NATIVE-PROGRAM-CONSUMER producer=" (.get (.get consumer build) output-directory)))))
  (cond
    (compile?
     ;; Core owns these helper libraries. Consume its admitted output through
     ;; the standard loader while Root Make resolves and links the producer.
     (worker)
     (.call (nix-publication-programs root) .with-imports producer))
    ((and (pair? args) (equal? (car args) "clean"))
     (worker)
     (producer))
    (else (producer))))
