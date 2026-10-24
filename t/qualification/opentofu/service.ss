;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Shared real-service fixture; Core and std/io own selection and lifetime.
(import :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :std/io/tempfile make-temporary-file-name clear-temporary-file!)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/encoding/json read-json)
        (only-in :std/list/walist waref)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :yuanxu/module-system/source/link yuanxu-load-modules)
        (only-in :yuanxu/observability/testing-fixture call-with-yuanxu-fixture)
        (only-in :yuanxu/observability/testing-case yuanxu-test-checkpoint)
        (only-in :yuanxu/ops/progress execution-progress!)
        (only-in :yuanxu/module-system/source/admission module-source-read current-module-source-observer)
        (only-in :yuanxu/ops/selected-packages SelectedPackages.))
(export call-with-service write-source rejects? empty-state?)

;; Reuse Core's fixture protocol so nested Ops calls share cancellation
;; registration and resource cleanup retains both body and release failures.
(def Workspace
  (.o .acquire:
      (lambda ()
        (let (directory (make-temporary-file-name "opentofu-service-"))
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

;; Report actual Core boundaries, not a timer or synthetic heartbeat.
(def (report-stage event _amount)
  (when (and (pair? event)
             (memq (car event) '(link-stage-start link-stage-end
                                package-stage-start package-stage-end)))
    (execution-progress! (cons 'opentofu event) 1)
    (displayln "PHASE " event " at=" (real-time)) (force-output)))

;; Read real state after destroy; command success alone is not cleanup evidence.
(def (empty-state? directory)
  (let* ((state (call-with-input-file (path-expand "terraform.tfstate" directory) read-json))
         (resources (waref state "resources" #f)))
    (or (null? resources) (and (vector? resources) (zero? (vector-length resources))))))

;; Each standard test gets one isolated service and one selection. Artifacts
;; remain real Nix outputs. Effects use explicit methods, so a lazy getter does
;; not retain a POO dependency recorder over an entire operational workflow.
;; Core's fixture protocol owns cancellation and release of the std/io resource.
(def (call-with-service action)
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
      (write-source (path-expand "gerbil.pkg" root-dir)
        "(package: opentofu-service-fixture prelude: :yuanxu/module-system/source/module-prelude)\n")
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
                    expression: ,(path-expand "t/fixtures/opentofu/selected-derivation.nix" project)
                    arguments: (.o derivation: ,derivation))
                  services: (.o opentofu: (.o Null: (.o message: "configured service")))))))))
      (def init-path (path-expand "init.ss" root-dir))
      (write-source init-path
        (call-with-output-string
          (lambda (port)
            (write `(yuanxu! :load-modules "./modules" mode: explicit
                      (json-schema @ ,(path-expand "core/modules/json-schema" project))
                      (nix @ ,(path-expand "modules/nix" project))
                      (funflow @ ,(path-expand "core/modules/funflow" project))
                      :services (opentofu)) port))))
      (displayln "PHASE source-selection at=" (real-time)) (force-output)
      (yuanxu-test-checkpoint 'opentofu-source-selection)
      (def selected-view
        (parameterize ((current-module-source-observer report-stage))
          (yuanxu-load-modules init-path
            module-view: (lambda (owner scope!) (.o identity: owner scope: (scope!))))))
      (def original-text (module-source-read config-path))
      (action
        (.o config: config-path original: original-text
          .source-scope:
          (lambda ()
            (parameterize ((current-module-source-observer report-stage))
              (.get selected-view modules modules services opentofu scope)))
          .prepare:
          (lambda ()
            (def packages
              (parameterize ((current-module-source-observer report-stage))
                (.call (.cc SelectedPackages. 'selection selected-view
                            'directory (path-expand "packages" root-dir)) .run)))
            (def ready-view (.call selected-view .with-packages packages))
            (def ready-value (.get ready-view modules modules services opentofu scope))
            (def recipe-value (.get ready-value Null))
            (.o ready-scope: ready-value recipe: recipe-value))
          .workspace:
          (lambda (name)
            (let (directory (path-expand name root-dir))
              (create-directory directory) directory)))))))
