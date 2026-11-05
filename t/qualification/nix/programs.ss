;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO program capabilities and ordinary Ops values for the existing Fixtures.
;;; Admission belongs to each build demand; this owner launches no process.
(import (only-in :clan/poo/object .o .cc .get .call)
        (only-in :yuanxu/ops/config Config)
        (only-in :gerbil/expander import-module current-expander-context)
        (only-in :yuanxu/module-system/source/deferred-declaration module-role-values)
        (only-in :std/make pkg-config-libs))
(export nix-publication-programs)
(def (nix-publication-programs root-value)
  ;; Use the same existing VM budget as the public Just test entry.
  (def vm-options
    (string-append "-:max-heap=" (getenv "GERBIL_TEST_MAX_HEAP" "2G") ",debug=q"))
  (.o (:: self [])
      core-exports:
      (.get (parameterize ((current-expander-context
                            (import-module (path-expand "core/init.ss" root-value) #f #t)))
              (module-role-values '(yuanxu.init.exports)))
            yuanxu.init.exports)
      support-demand:
      (.call (.get self core-exports tests) .for-files
        (map (cut path-expand <> root-value)
          '("core/t/qualification/build-publication/worker.ss"
            "core/t/qualification/build-publication/store-producer.ss"))
        (map (cut path-expand <> root-value)
          '("t/qualification/nix/build.ss" "t/qualification/nix/programs.ss"))
        (list (list exe: "t/qualification/build-publication/worker"
                    bin: "nix-publication-worker"
                    "-ld-options" (pkg-config-libs "libcrypto" "libssl"))))
      worker-demand:
      (.call (.get self core-exports tests) .for-files
        (list (path-expand "core/t/qualification/build-publication/worker.ss" root-value))
        '() (.get self support-demand source std-make-spec))
      producer-demand:
      (let (exports
            (.get (parameterize ((current-expander-context
                                  (import-module (path-expand "init.ss" root-value) #f #t)))
                    (module-role-values '(agentic-ai-lab.init.exports)))
                  agentic-ai-lab.init.exports))
        ;; Invocation consumes the same declaration as preparation, including
        ;; the Source interfaces used by generated service modules. Do not
        ;; narrow its issued publication to just the executable's path.
        (.call (.get exports tests) .for-files
          (map (cut path-expand <> root-value)
            '("scenarios/aws/types.ss" "scenarios/aws/objects.ss"
              "modules/nix/objects.ss" "modules/services/opentofu/objects.ss"
              "t/qualification/nix/tools.ss"))
          (map (cut path-expand <> root-value)
            '("t/qualification/nix/build.ss" "t/qualification/nix/programs.ss"))
          (list (list exe: "t/qualification/nix/tools" bin: "build-publication-tools"
                      "-ld-options" (pkg-config-libs "libcrypto" "libssl")))))
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
