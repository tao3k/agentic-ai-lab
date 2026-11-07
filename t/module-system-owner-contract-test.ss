;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module owner contracts stay separate from activation tests.

(import (only-in :clan/poo/type Record String List)
        (only-in :clan/poo/object-contract diagnose)
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in "../core/t/qualification/testing/directory.ss" write-source)
        (only-in "../core/t/qualification/service-publication/fixtures.ss" ServicesFixture refused)
        (only-in :yuanxu/module-system/source/admission module-source-read)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :clan/poo/object .o .def .cc .ref .get .call object-slots $constant-slot-spec? $self-slot-spec?)
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/module-system/authoring/syntax
        :agentic-ai-lab/modules/module-authoring/module-option-projection
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/doctor-presentation
                 agenticAiLabModuleDoctorPresentation)
        :yuanxu/module-system/catalog/values
        :yuanxu/module-system/projection/option-objects
        :yuanxu/module-system/projection/option-validation
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :yuanxu/module-system/funs
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :yuanxu/module-system/catalog/objects)

(export module-system-owner-contract-test)

(def (source-datum-has-module-prefix? value prefix except-prefix)
  (cond
   ((symbol? value)
    (let (name (symbol->string value))
      (and (string-prefix? prefix name)
           (not (string-prefix? except-prefix name)))))
   ((pair? value)
    (or (source-datum-has-module-prefix? (car value) prefix except-prefix)
        (source-datum-has-module-prefix? (cdr value) prefix except-prefix)))
   ((vector? value)
    (source-datum-has-module-prefix? (vector->list value) prefix except-prefix))
   (else #f)))

(def (source-port-has-module-prefix? port prefix except-prefix)
  (let loop ()
    (let (value (read port))
      (cond
       ((eof-object? value) #f)
       ((source-datum-has-module-prefix? value prefix except-prefix) #t)
       (else (loop))))))

;;; This suite exercises direct owner imports without an aggregate module API.
;; : TestSuite
(def module-system-owner-contract-test
  (test-suite "agentic-ai-lab module owner contracts"
    (yuanxu-test-case "keeps the Core module entry independent of product imports"
      (check-equal?
       (call-with-input-file
        "core/module-system/interface.ss"
        (lambda (port)
          (source-port-has-module-prefix?
           port
           ":agentic-ai-lab/modules/"
           ":yuanxu/")))
       #f)
      (check-equal?
       (source-datum-has-module-prefix?
        '(import :agentic-ai-lab/modules/workflow/cicd-runtime)
        ":agentic-ai-lab/modules/" ":yuanxu/")
       #t))
    (yuanxu-test-case "builds Marlin-style interface config descriptors"
      (let* ((interface
              (yuanxu-module-interface
               "WorkspaceProfile"
               (Record workspace-root: [String default: "workspace"]
                   surface: [String constant: "agentic-ai-lab"])
               '((owner . "agentic-ai-lab") (surface . "module-system"))))
             (source (yuanxu-local-source "modules/workspace.ss"))
             (derived-interface
              (.o (:: @ interface)
                  schemas: (Record derived-only:
                                [String constant: "derived"])))
             (module
              (agentic-ai-lab-modules
               interface
               (.o id: 'workspace
                   imports: '()
                   config:
                   (.o workspace-root: "demo"
                       surface: "agentic-ai-lab")
                   extensions: (yuanxu-extensions 'workspace-extension)
                   scripts: (list 'workspace-script)
                   metadata: '((layer . "base"))
                   group: 'tools
                   flags: '(+fast +gerbil)
                   features: '(poo c4)
                   depth: (cons -10 10)
                   phase-files:
                   '((init . "init.ss")
                     (config . "config.ss")
                     (packages . "packages.ss"))
                   hooks:
                   '((before-init . (prepare-workspace))
                     (after-config . (publish-workspace)))
                   source-ref: source)))
             (schemas (agentic-ai-lab-module-option-schemas module))
             (configs (agentic-ai-lab-module-option-configs module))
             (receipts (agentic-ai-lab-module-option-validation-receipts module)))
        (check-equal? (agentic-ai-lab-module-descriptor? module) #t)
        (check-equal? (agentic-ai-lab-module-name module) 'workspace)
        (check-equal? (yuanxu-module-interface?
                       (agentic-ai-lab-module-interface-object module))
                      #t)
        (check-equal?
         (.ref (yuanxu-module-interface-schema-spec interface "surface")
               'constant)
         "agentic-ai-lab")
        (check-equal?
         (yuanxu-module-interface-schema-spec interface "missing")
         #f)
        (check-equal?
         (.ref (yuanxu-module-interface-schema-spec
                derived-interface
                "derived-only")
               'constant)
         "derived")
        (check-equal?
         (yuanxu-module-interface-schema-spec
          derived-interface
          "surface")
         #f)
        (check-equal? (cdr (assoc 'workspace-root (agentic-ai-lab-module-options module)))
                      "demo")
        (check-equal? (agentic-ai-lab-module-extensions module) '(workspace-extension))
        (check-equal? (agentic-ai-lab-module-scripts module) '(workspace-script))
        (check-equal? (agentic-ai-lab-module-metadata module) '((layer . "base")))
        (check-equal? (agentic-ai-lab-module-group module) 'tools)
        (check-equal? (agentic-ai-lab-module-flags module) '(+fast +gerbil))
        (check-equal? (agentic-ai-lab-module-features module) '(poo c4))
        (check-equal? (yuanxu-module-depth-value module 'init) -10)
        (check-equal? (yuanxu-module-depth-value module 'config) 10)
        (check-equal? (yuanxu-module-phase-file module 'config) "config.ss")
        (check-equal? (yuanxu-module-hook-values module 'before-init)
                      '(prepare-workspace))
        (check-equal? (yuanxu-module-flag-enabled? module '+fast) #t)
        (check-equal? (agentic-ai-lab-module-active? module '+fast '-slow) #t)
        (check-equal? (agentic-ai-lab-module-active? module '+missing) #f)
        (check-equal? (yuanxu-module-source-ref=?
                       (agentic-ai-lab-module-descriptor-source-ref module)
                       source)
                      #t)
        (check-equal? (length schemas) 2)
        (check-equal? (length configs) 2)
        (check-equal? (map (cut .ref <> 'code) receipts)
                      '(ok ok))))
    (yuanxu-test-case "real facade and projection leave unclaimed payloads unforced"
      (def reads 0)
      (def Config (.o endpoint: (begin (set! reads (+ reads 1)) "localhost")
                      unclaimed: (error "unclaimed option forced")))
      (def interface (yuanxu-module-interface "Network" (Record endpoint: [String]) '()))
      (def module
        (agentic-ai-lab-modules interface
          (.o id: 'network config: Config options: (error "unused fallback options forced"))))
      (check-equal? reads 0)
      (def candidates (agentic-ai-lab-module-option-configs module))
      (check-equal? reads 0)
      (check-equal? (length candidates) 2)
      (def receipts (agentic-ai-lab-module-option-validation-receipts module))
      (check-equal? reads 1)
      (check-equal? (length receipts) 2)
      (check-equal? (map (cut .ref <> 'id) receipts) (map (cut .ref <> 'id) candidates))
      (check-equal? (length (filter (lambda (receipt) (eq? (.ref receipt 'code) 'ok)) receipts)) 1)
      (check-equal? (length (filter (lambda (receipt) (eq? (.ref receipt 'code) 'missing-schema)) receipts)) 1))
    (yuanxu-test-case "cached options follow the final receiver and retain constant constructor slots"
      (def interface (yuanxu-module-interface "Network" (Record endpoint: [String default: "localhost"]) '()))
      (def parent (agentic-ai-lab-modules interface (.o id: 'network)))
      (def cached (agentic-ai-lab-module-options parent))
      (check-equal? (cdr (assoc 'endpoint cached)) "localhost")
      (.def (child @ parent) config: =>.+ (.o endpoint: "release.internal"))
      (def child-options (agentic-ai-lab-module-options child))
      (check-equal? (cdr (assoc 'endpoint child-options)) "release.internal")
      (check-equal? (eq? (agentic-ai-lab-module-options parent) cached) #t)
      (check-equal? (eq? (agentic-ai-lab-module-options child) child-options) #t)
      (check-equal? (cdr (assoc 'endpoint cached)) "localhost")
      (check-equal? (.ref (car (agentic-ai-lab-module-option-validation-receipts child)) 'valid?) #t)
      (.def (bad @ child) config: =>.+ (.o endpoint: 42))
      (def bad-receipt (car (agentic-ai-lab-module-option-validation-receipts bad)))
      (check-equal? (.ref bad-receipt 'valid?) #f)
      (check-equal? (.ref (car (.ref bad-receipt 'messages)) 'path) '(endpoint))
      ;; The actual runtime specifications, not shallow closure counts, distinguish
      ;; constant captured arguments from the single receiver-bound formula.
      (check-equal? (map car (filter (lambda (entry) ($self-slot-spec? (cdr entry)))
                                    (object-slots parent))) '(options))
      (check-equal? (andmap (lambda (entry)
                             (or (eq? (car entry) 'options) ($constant-slot-spec? (cdr entry))))
                           (object-slots parent)) #t)
      (def rows '((duplicate . 1) (duplicate . 2)))
      (def legacy (make-empty-agentic-ai-lab-module-descriptor 'legacy '() rows))
      (check-equal? (eq? (agentic-ai-lab-module-options legacy) rows) #t))
    (yuanxu-test-case "final declaration detects missing fields and replaces the parent schema index"
      (def interface (yuanxu-module-interface "Network" (Record endpoint: [String]) '()))
      (def parent (agentic-ai-lab-modules interface (.o id: 'network config: (.o endpoint: "localhost"))))
      (def cached (agentic-ai-lab-module-option-validation-receipts parent))
      (yuanxu-module-interface-schema-spec interface "endpoint")
      (.def (missing @ parent) config: (.o))
      (def failures (agentic-ai-lab-module-option-validation-receipts missing))
      (check-equal? (map (cut .ref <> 'code) failures) '(missing-field))
      (check-equal? (.ref (car (.ref (car failures) 'messages)) 'path) '(endpoint))
      (.def (wrong-config @ parent) config: 42)
      (check-equal? (map (cut .ref <> 'code)
                        (agentic-ai-lab-module-option-validation-receipts wrong-config))
                    '(expected-object))
      (.def (child @ parent)
        schemas: (Record socket: [String metadata: '((owner . child))])
        config: (.o socket: "/tmp/database.sock"))
      (def receipts (agentic-ai-lab-module-option-validation-receipts child))
      (check-equal? (map (cut .ref <> 'id) receipts) '("socket"))
      (check-equal? (map (cut .ref <> 'code) receipts) '(ok))
      (check-equal? (.ref (car receipts) 'metadata) '((owner . child)))
      (check-equal? (map (cut .ref <> 'code) cached) '(ok)))
    (yuanxu-test-case "original whole Record membership is visible in product previews"
      (def checks 0)
      (def declaration
        (.o (:: @ (Record start: [String] finish: [String]))
          .element?: (lambda (candidate)
                       (set! checks (+ checks 1))
                       (equal? (.ref candidate 'start) (.ref candidate 'finish)))))
      (def interface (yuanxu-module-interface "Window" declaration '()))
      (def module
        (agentic-ai-lab-modules interface
          (.o id: 'window config: (.o start: "left" finish: "right"))))
      (check-equal? checks 0)
      (def receipts (agentic-ai-lab-module-option-validation-receipts module))
      (check-equal? checks 1)
      (check-equal? (map (cut .ref <> 'code) receipts) '(ok ok class-rejected))
      (check-equal? (.ref (caddr receipts) 'id) #f)
      (check-equal? (.ref (caddr receipts) 'source-module) 'window))
    (yuanxu-test-fixture "real service preview sharing never substitutes for fresh publication admission"
      (fixture ServicesFixture)
      (def publication (.get fixture publication))
      (def parent (.get publication value))
      (def cached-plan (.get parent plan))
      (def actual-type (.get publication contract value-contract))
      (def shape (Record application: [actual-type]))
      (def analyses 0)
      ;; Count runtime Record dispatch while retaining the real maintained
      ;; Application value Contract. Source/context obligations remain .admit's job.
      (def declaration
        (.cc shape .diagnose: (lambda (candidate path)
                                (set! analyses (+ analyses 1))
                                (diagnose shape candidate path))))
      (def module
        (agentic-ai-lab-modules (yuanxu-module-interface "ApplicationPreview" declaration '())
          (.o id: 'services-preview config: (.o application: parent))))
      (def workflow (agentic-ai-lab-module-workflow module))
      (.def (doctor @ (agenticAiLabModuleDoctorPresentation (yuanxuModuleCatalog module) 'services-preview))
        evaluation: (.get workflow evaluation))
      (def closure (.get workflow evaluation modules))
      (check-equal? (.get doctor module-ids) '(services-preview))
      (.get doctor doctor-status)
      (.get doctor import-graph)
      (.get doctor contributions)
      (check-equal? (eq? (.get doctor evaluation modules) closure) #t)
      (check-equal? analyses 0)
      (def roots (.get workflow root-validation-receipts))
      (.get workflow validation-receipts)
      (check-equal? (.get doctor validation-receipt-count) 1)
      (check-equal? analyses 1)
      (check-equal? (map (cut .get <> valid?) roots) '(#t))
      (.def (release @ parent)
        config: =>.+ (.o postgresql: =>.+ (.o settings: =>.+ (.o port: 5433))))
      (.def (child-workflow @ workflow)
        config: =>.+ (.o config: =>.+ (.o application: release)))
      (check-equal? (map (cut .get <> valid?) (.get child-workflow validation-receipts)) '(#t))
      (.get child-workflow root-validation-receipts)
      (check-equal? analyses 2)
      (check-equal? (.get cached-plan postgresql port) 5432)
      (check-equal? (.get release plan postgresql port) 5433)
      (check-equal? (length (.get publication context contributions)) 2)
      (defvalues (receipt next failure) (.call publication .publish parent release))
      (check-equal? failure #f)
      (check-equal? (.get receipt accepted?) #t)
      (check-equal? (.get next plan gitea database-port) 5433)
      (def path (path-expand "modules/services/postgresql/postgresql.json" (.get fixture source)))
      (write-source path (string-append (module-source-read path) "\n"))
      ;; The cached preview still exists; it cannot authorize this publication.
      (check-equal? (eq? roots (.get workflow root-validation-receipts)) #t)
      (refused publication parent release "selected configuration asset changed"))
    (yuanxu-test-case "inline imports join activation closure and workflow receipts"
      (let* ((child-task
              (make-task-family-descriptor 'inline-job
                                           'inline-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (child
              (make-agentic-ai-lab-module-descriptor
               'child
               '()
               (make-task-family-registry 'child-tasks (list child-task))
               (make-flow-declaration-registry 'child-flows '())
               '((layer . "child"))))
             (interface
              (yuanxu-module-interface
               "RootProfile"
               (Record surface: [String default: "root"])
               '((owner . "agentic-ai-lab"))))
             (root
              (agentic-ai-lab-modules
               interface
               (.o id: 'root
                   imports:
                   (yuanxu-imports
                    (yuanxu-import ":agentic-ai-lab/modules/root#child" child))
                   config: (.o surface: "root")
                   flags: '(+root)
                   depth: (cons 10 10)
                   hooks: '((before-init . (root-hook)))
                   extensions: (yuanxu-extensions 'root-extension)
                   scripts: (list 'root-script))))
             (activation (activate-agentic-ai-lab-modules (list root)))
             (catalog (yuanxuModuleCatalog root))
             (eval-result (agentic-ai-lab-eval-modules catalog 'root '("runtime-hook")))
             (evaluation (agentic-ai-lab-module-evaluate root))
             (presentation (agentic-ai-lab-module-system-presentation
                            catalog
                            'root
                            '("runtime-hook"))))
        (check-equal? (agentic-ai-lab-module-names
                       (agentic-ai-lab-module-activation-modules activation))
                      '(root child))
        (check-equal? (task-family-name
                       (task-family-for-kind-in
                        (agentic-ai-lab-module-activation-task-registry activation)
                        'inline-job))
                      'inline-job)
        (check-equal? (.ref eval-result 'module-count) 2)
        (check-equal? (.ref eval-result 'hook-count) 1)
        (check-equal? (.ref evaluation 'init-module-ids) '(child root))
        (check-equal? (agentic-ai-lab-module-value-catalog-active? catalog 'root '+root) #t)
        (check-equal? (agentic-ai-lab-module-value-catalog-active? catalog 'root '+missing) #f)
        (check-equal? (.ref eval-result 'extension-count) 1)
        (check-equal? (agentic-ai-lab-module-group root) agentic-ai-lab-brand-group)
        (check-equal? (.ref eval-result 'brand-name) agentic-ai-lab-brand-name)
        (check-equal? (.ref eval-result 'scheme-owner)
                      agentic-ai-lab-scheme-owner)
        (check-equal? (.ref presentation 'kind)
                      agentic-ai-lab-module-system-presentation-kind)
        (check-equal? (.ref presentation 'brand-name) agentic-ai-lab-brand-name)
        (check-equal? (.ref presentation 'import-graph-owner)
                      "agentic-ai-lab-module-system")
        (check-equal? (.ref presentation 'runtime-capability-projection-kind)
                      "agentic-ai-lab.modules.runtime-capability-projection.v1")
        (check-equal? (.ref presentation 'runtime-object-family-count) 8)
        (check-equal? (.ref presentation 'runtime-object-families)
                      '(agent-profile
                        agent-harness
                        agent-session
                        session-agent-graph
                        agent-operation
                        workflow-run
                        dispatch-receipt
                        runtime-snapshot))
        (check-equal? (member 'waiting-human
                              (.ref presentation 'runtime-snapshot-statuses))
                      '(waiting-human completed errored disconnected))
        (check-equal? (member 'admit-dispatch
                              (.ref presentation 'runtime-handoff-contracts))
                      '(admit-dispatch
                        open-agent-session
                        execute-agent-operation
                        stream-events
                        read-runtime-snapshot))))))
