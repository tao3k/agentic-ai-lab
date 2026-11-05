#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Core init owns this native worker and its producer support libraries.
;;; Each recovery invocation starts the existing Core main in a fresh process;
;;; it does not initialize the Root producer/ServiceFixture dispatcher.
(import (only-in :clan/poo/object .get .call)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./core/init.ss" yuanxu.init.exports)
        (only-in "./build-spec.ss"
          agentic-ai-lab-nix-worker-demand agentic-ai-lab-nix-program-consumer)
        (only-in :yuanxu/module-system/building/artifacts retain-test-support-subset!))
(def root (path-directory (this-source-file)))
(def core-root (path-expand "core" root))
(def demand (agentic-ai-lab-nix-worker-demand yuanxu.init.exports root))
(def (build-worker args)
  (defbuild-script
    ((.get demand std-make-spec))
    prefix: "yuanxu"
    srcdir: core-root)
  (apply main args))
(def (main . args)
  (build-worker args)
  (when (or (null? args) (equal? (car args) "compile"))
    ;; Transfer the runtime's exact declared consumer through the existing
    ;; subset issuer. No path alias or unsigned output is published here.
    (let (consumer
          (agentic-ai-lab-nix-program-consumer yuanxu.init.exports demand
            (path-expand "t/qualification/build-publication/worker.ss" core-root)))
      (retain-test-support-subset! (.get demand build) (.get consumer build))
      (displayln "NATIVE-PROGRAM-CONSUMER worker=" (.get (.get consumer build) output-directory)))))
