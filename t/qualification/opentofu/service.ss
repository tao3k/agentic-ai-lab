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
        (only-in :agentic-ai-lab/modules/services/opentofu/func opentofu-service-configuration)
        (only-in "./objects.ss" configured-opentofu-modules)
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
(def (call-with-service action instantiate: (instantiate-command #f)
                        observe-stages?: (observe-stages? #t))
  (call-with-yuanxu-fixture Workspace
    (lambda (root-dir)
      (def stage-observer (and observe-stages? report-stage))
      (def project (current-directory))
      (displayln "PHASE producer-derivation at=" (real-time)) (force-output)
      (yuanxu-test-checkpoint 'opentofu-producer-derivation)
      (def producer-derivation
        (.call (.o (:: @ NixSource.)
                 expression: (path-expand "t/fixtures/opentofu/null-provider-artifacts.nix" project))
               .instantiate))
      (def config-path (path-expand "config.nix" root-dir))
      (def expression (path-expand "t/fixtures/opentofu/selected-derivation.nix" project))
      (def checker (path-expand "modules/nix/source-inputs.nix" project))
      (write-source config-path
        (call-with-output-string (lambda (port) (display "import " port) (write expression port))))
      (def original-text (module-source-read config-path))
      ;; The temporary input is evaluated by Nix and guarded alongside the real
      ;; declaration and its transitive expression files.
      (def baseline
        (.o (:: @ NixSource.)
          expression: config-path
          arguments: (.o derivation: producer-derivation)
          source-inputs: (list (cons config-path original-text)
                               (cons expression (module-source-read expression))
                               (cons checker (module-source-read checker)))))
      (def source
        (if instantiate-command
          (.cc baseline 'config (.cc (.get baseline config) 'instantiate instantiate-command))
          baseline))
      (def init-path (path-expand "init.ss" root-dir))
      (write-source init-path
        (call-with-output-string
          (lambda (port)
            (write `(yuanxu!
                      :load-modules ,(path-expand "core/modules" project)
                      mode: explicit rename: Core (json-schema) (funflow)
                      :load-modules ,(path-expand "modules" project) mode: explicit rename: Lab
                      (nix) :services (opentofu)) port))))
      (displayln "PHASE source-selection at=" (real-time)) (force-output)
      (yuanxu-test-checkpoint 'opentofu-source-selection)
      (def (configure scope)
        (.cc scope 'config
          (.cc (.get scope config) 'source source
            'services (.o opentofu: (.o Null: (.o message: "configured service"))))))
      (def selected-view
        (parameterize ((current-module-source-observer stage-observer))
          (configured-opentofu-modules init-path configure opentofu-service-configuration)))
      (action
        (.o config: config-path original: original-text
          .source-scope:
          (lambda ()
            (parameterize ((current-module-source-observer stage-observer))
              (.get selected-view modules Lab services opentofu)))
          .prepare:
          (lambda ()
            (def packages
              (parameterize ((current-module-source-observer stage-observer))
                (.call (.cc SelectedPackages. 'selection selected-view
                            'directory (path-expand "packages" root-dir)) .run)))
            (def ready-view (.call selected-view .with-packages packages))
            (def ready-value (.get ready-view modules Lab services opentofu))
            (def recipe-value (.get ready-value Null))
            (.o ready-scope: ready-value recipe: recipe-value))
          .workspace:
          (lambda (name)
            (let (directory (path-expand name root-dir))
              (create-directory directory) directory)))))))
