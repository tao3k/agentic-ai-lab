;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO program capabilities and ordinary Ops values for the existing Fixtures.
;;; Admission belongs to each build demand; this owner launches no process.
(import (only-in :clan/poo/object .o .cc .get .call)
        (only-in :yuanxu/ops/config Config)
        (only-in :yuanxu/module-system/building/test-projection module-test-source-binding)
        (only-in "../../../build-spec.ss"
          agentic-ai-lab-nix-worker-demand agentic-ai-lab-nix-producer-demand
          agentic-ai-lab-nix-program-consumer))
(export nix-publication-programs)
(def (nix-publication-programs root-value)
  ;; Use the same existing VM budget as the public Just test entry.
  (def vm-options
    (string-append "-:max-heap=" (getenv "GERBIL_TEST_MAX_HEAP" "2G") ",debug=q"))
  (.o (:: self [])
      core-exports:
      (module-test-source-binding (path-expand "core/init.ss" root-value)
                                  'yuanxu.init.exports)
      support-demand:
      (agentic-ai-lab-nix-worker-demand (.get self core-exports) root-value)
      worker-demand:
      (agentic-ai-lab-nix-program-consumer (.get self core-exports)
        (.get self support-demand)
        (path-expand "core/t/qualification/build-publication/worker.ss" root-value))
      producer-demand:
      (let (exports
            (module-test-source-binding (path-expand "init.ss" root-value)
                                        'agentic-ai-lab.init.exports))
        ;; Invocation consumes the same declaration as preparation, including
        ;; the Source interfaces used by generated service modules. Do not
        ;; narrow its issued publication to just the executable's path.
        (agentic-ai-lab-nix-producer-demand exports root-value))
      ;; The dependency is an issued build, not an ambient library directory.
      ;; Its source/products are checked before use and after successful work;
      ;; the ordinary Gerbil load path is restored on every exit.
      .with-imports:
      (lambda (action)
        (def build (.get self support-demand build))
        ((.get build admit-artifacts))
        (def paths (load-path))
        (def directory (.get build output-directory))
        (dynamic-wind
          (lambda () (add-load-path! directory))
          (lambda ()
            (def value (action))
            ((.get build admit-artifacts))
            value)
          (lambda () (set-load-path! paths))))
      .worker:
      (lambda arguments
        (.cc Config directory: root-value timeout: 300
          command: (append
            (list (.call (.get self worker-demand build) .program
                    'yuanxu/t/qualification/build-publication/worker)
                  vm-options) arguments)))
      .producer:
      (lambda (role . arguments)
        (.call self .with-imports
          (lambda ()
            (def build (.get self producer-demand build))
            ((.get build admit-artifacts))
            ;; The child expander needs the admitted interfaces as well as the
            ;; linked program. Carry their existing capability-owned directories
            ;; through Gerbil's standard environment; never depend on a warm
            ;; product installation or a vanished compiler sandbox.
            (def libraries
              (string-append (.get build output-directory) ":"
                (.get self support-demand build output-directory)))
            (def inherited (getenv "GERBIL_LOADPATH" ""))
            (.cc Config
              directory: (if (string=? role "store") (path-expand "core" root-value) root-value)
              timeout: 300
              environment:
              (.o GERBIL_LOADPATH:
                (if (equal? inherited "") libraries
                  (string-append libraries ":" inherited)))
              command: (append
                (list (.call build .program
                        'agentic-ai-lab/t/qualification/nix/tools)
                      vm-options role) arguments)))))))
