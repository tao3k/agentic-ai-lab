;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Shared real-service fixture; Core and std/io own selection and lifetime.
(import :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :std/io/tempfile call-with-temporary-file-name
                 make-temporary-file-name clear-temporary-file!)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/encoding/json read-json)
        (only-in :std/list/walist waref)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-completion-observer)
        (only-in :tao3k/yuanxu/module-system/source/link yuanxu-load-modules)
        (only-in :tao3k/yuanxu/observability/testing-fixture call-with-yuanxu-fixture)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-checkpoint)
        (only-in :tao3k/yuanxu/ops/progress execution-progress!)
        (only-in :tao3k/yuanxu/module-system/source/admission module-source-read)
        (only-in :tao3k/yuanxu/ops/selected-packages SelectedPackages.))
(export call-with-service write-source rejects? empty-state?)

;; Reuse Core's fixture protocol so nested Ops calls share cancellation
;; registration and resource cleanup retains both body and release failures.
(def Workspace
  (.o .acquire:
      (lambda ()
        ;; The isolated roles still belong to this real package. Their
        ;; declared public library roots resolve against its own gerbil.pkg.
        (let (directory (make-temporary-file-name (path-expand ".opentofu-service-" (current-directory))))
          (create-directory directory) directory))
      .release: clear-temporary-file!))

;; Mutations remain fixture-owned and visible to the existing source guards.
(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))

;; Inspect the standard error message without formatting a whole POO graph.
(def (rejects? pattern action)
  (with-catch
    (lambda (exception)
      (let (text (if (Error? exception) (Error-message exception)
                    (call-with-output-string (cut display-exception exception <>))))
        (unless (pregexp-match pattern text) (displayln text))
        (and (pregexp-match pattern text) #t)))
    (lambda () (action) #f)))

;; Each fixture has its own completed work, even in a shared Harness.
(def (make-service-progress-observer directory)
  (def completed 0)
  (def key (cons 'opentofu directory))
  (def caller-observer (current-nix-process-completion-observer))
  ;; Read-only CLI queries may emit only informational records. Report their
  ;; actual completion without installing an open Module System observer.
  (lambda (command seconds completed?)
    (when caller-observer (caller-observer command seconds completed?))
    (when completed?
      (set! completed (1+ completed))
      (execution-progress! key completed))))

;; Read real state after destroy; command success alone is not cleanup evidence.
(def (empty-state? directory)
  (let* ((state (call-with-input-file (path-expand "terraform.tfstate" directory) read-json))
         (resources (waref state "resources" #f)))
    (or (null? resources) (and (vector? resources) (zero? (vector-length resources))))))

;; Each standard test gets one isolated service and one selection. Artifacts
;; remain real Nix outputs. Effects use explicit methods, so a lazy getter does
;; not retain a POO dependency recorder over an entire operational workflow.
;; Core's fixture protocol owns cancellation and release of the std/io resource.
(def (call-with-service action instantiate: (instantiate-command #f)
                        report-progress?: (report-progress? #t))
  ;; The init declaration owns the same package kernel as the library targets
  ;; published by Nix and OpenTofu. The isolated roles have their own window.
  (call-with-temporary-file-name (path-expand ".opentofu-init-" (current-directory))
    (cut call-with-service-at action instantiate-command report-progress? <>)
    suffix: ".ss"))

(def (call-with-service-at action instantiate-command report-progress? init-path)
  (call-with-yuanxu-fixture Workspace
    (lambda (root-dir)
      (def project (current-directory))
      (def maintained (path-expand "modules/services/opentofu" project))
      (def service-dir (path-expand "modules/services/opentofu" root-dir))
      (displayln "PHASE producer-derivation at=" (real-time)) (force-output)
      (yuanxu-test-checkpoint 'opentofu-producer-derivation)
      (def derivation
        (.call (.o (:: @ NixSource.)
                 expression: (path-expand "t/fixtures/opentofu/null-provider-artifacts.nix" project))
               .instantiate))
      (create-directory* service-dir)
      (for-each
        (lambda (name)
          (when (string-suffix? ".ss" name)
            (copy-file (path-expand name maintained) (path-expand name service-dir))))
        (directory-files maintained))
      (def config-path (path-expand "config.ss" service-dir))
      (write-source config-path
        (call-with-output-string
          (lambda (port)
            (for-each (lambda (form) (write form port) (newline port))
              `((import :clan/poo/object
                   (rename-in (only-in :agentic-ai-lab/modules/services/opentofu/config
                                Config OpenTofuProviderConfig) (Config Defaults))
                   (only-in :agentic-ai-lab/modules/nix/objects NixSource.))
                (export Config OpenTofuProviderConfig)
                (.def (Config @ Defaults)
                  source: (.o (:: @ NixSource.)
                    ,@(if instantiate-command
                        (list 'config: `(.cc (.get NixSource. config)
                                         'instantiate ,instantiate-command)) '())
                    expression: ,(path-expand "t/fixtures/opentofu/selected-derivation.nix" project)
                    arguments: (.o derivation: ,derivation))
                  services: (.o opentofu: (.o Null: (.o message: "configured service")))))))))
      (write-source init-path
        (call-with-output-string
          (lambda (port)
            (write `(yuanxu! :load-modules ,(path-expand "modules" root-dir) mode: explicit
                      (json-schema @ ,(path-expand "core/modules/json-schema" project))
                      (nix @ ,(path-expand "modules/nix" project))
                      (funflow @ ,(path-expand "core/modules/funflow" project))
                      :services (opentofu)) port))))
      (displayln "PHASE source-selection at=" (real-time)) (force-output)
      (yuanxu-test-checkpoint 'opentofu-source-selection)
      (def selected-view
        (yuanxu-load-modules init-path
          module-view: (lambda (owner scope!) (.o identity: owner scope: (scope!)))))
      (def original-text (module-source-read config-path))
      (def service
        (.o config: config-path original: original-text
          .source-scope:
          (lambda () (.get selected-view modules modules services opentofu scope))
          .prepare:
          (lambda ()
            (def packages
              (.call (.cc SelectedPackages. 'selection selected-view
                          'directory (path-expand "packages" root-dir)) .run))
            (def ready-view (.call selected-view .with-packages packages))
            (def ready-value (.get ready-view modules modules services opentofu scope))
            (def recipe-value (.get ready-value Null))
            (.o ready-scope: ready-value recipe: recipe-value))
          .workspace:
          (lambda (name)
            (let (directory (path-expand name root-dir))
              (create-directory directory) directory))))
      (if report-progress?
        (parameterize
            ((current-nix-process-completion-observer (make-service-progress-observer root-dir)))
          (action service))
        (action service)))))
