;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module owner contracts stay separate from activation tests.

(import (only-in :core/observability/testing-case poo-flow-test-case)
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
        (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/workflow/control-plane/api
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/selection/objects
        :poo-flow/modules/module-authoring/module-descriptor
        :core/module-system/authoring/syntax
        :poo-flow/modules/module-authoring/module-option-projection
        :poo-flow/modules/workflow/scenario/configuration/module-runtime-presentation
        :core/module-system/catalog/values
        :core/module-system/projection/option-objects
        :core/module-system/projection/option-validation
        :core/module-system/source/imports
        :core/module-system/source/objects
        :core/module-system/funs
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :core/module-system/catalog/objects
        :poo-flow/modules/workflow/scenario/configuration/presentation-config
        :poo-flow/modules/workflow/scenario/configuration/interface)

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
  (test-suite "poo-flow module owner contracts"
    (poo-flow-test-case "keeps the Core module entry independent of product imports"
      (check-equal?
       (call-with-input-file
        "core/module-system/interface.ss"
        (lambda (port)
          (source-port-has-module-prefix?
           port
           ":poo-flow/modules/"
           ":core/")))
       #f)
      (check-equal?
       (source-datum-has-module-prefix?
        '(import :poo-flow/modules/funflow/interface)
        ":poo-flow/modules/" ":core/")
       #t))
    (poo-flow-test-case "builds Marlin-style interface config descriptors"
      (let* ((interface
              (poo-flow-module-interface
               "WorkspaceProfile"
               (.o workspace-root: (poo-flow-string-default "workspace")
                   surface: (poo-flow-string-constant "poo-flow"))
               '((owner . "poo-flow") (surface . "module-system"))))
             (source (poo-flow-local-source "modules/workspace.ss"))
             (derived-interface
              (.o (:: @ interface)
                  schemas: (.o derived-only:
                                (poo-flow-string-constant "derived"))))
             (module
              (poo-flow-modules
               interface
               (.o id: 'workspace
                   imports: '()
                   config:
                   (.o workspace-root: "demo"
                       surface: "poo-flow")
                   extensions: (poo-flow-extensions 'workspace-extension)
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
             (schemas (poo-flow-module-option-schemas module))
             (configs (poo-flow-module-option-configs module))
             (receipts (poo-flow-module-option-validation-receipts module)))
        (check-equal? (poo-flow-module-descriptor? module) #t)
        (check-equal? (poo-flow-module-name module) 'workspace)
        (check-equal? (poo-flow-module-interface?
                       (poo-flow-module-interface-object module))
                      #t)
        (check-equal?
         (.ref (poo-flow-module-interface-schema-spec interface "surface")
               'constant)
         "poo-flow")
        (check-equal?
         (poo-flow-module-interface-schema-spec interface "missing")
         #f)
        (check-equal?
         (.ref (poo-flow-module-interface-schema-spec
                derived-interface
                "derived-only")
               'constant)
         "derived")
        (check-equal?
         (poo-flow-module-interface-schema-spec
          derived-interface
          "surface")
         #f)
        (check-equal? (cdr (assoc 'workspace-root (poo-flow-module-options module)))
                      "demo")
        (check-equal? (poo-flow-module-extensions module) '(workspace-extension))
        (check-equal? (poo-flow-module-scripts module) '(workspace-script))
        (check-equal? (poo-flow-module-metadata module) '((layer . "base")))
        (check-equal? (poo-flow-module-group module) 'tools)
        (check-equal? (poo-flow-module-flags module) '(+fast +gerbil))
        (check-equal? (poo-flow-module-features module) '(poo c4))
        (check-equal? (poo-flow-module-depth-value module 'init) -10)
        (check-equal? (poo-flow-module-depth-value module 'config) 10)
        (check-equal? (poo-flow-module-phase-file module 'config) "config.ss")
        (check-equal? (poo-flow-module-hook-values module 'before-init)
                      '(prepare-workspace))
        (check-equal? (poo-flow-module-flag-enabled? module '+fast) #t)
        (check-equal? (poo-flow-module-active? module '+fast '-slow) #t)
        (check-equal? (poo-flow-module-active? module '+missing) #f)
        (check-equal? (poo-flow-module-source-ref=?
                       (poo-flow-module-descriptor-source-ref module)
                       source)
                      #t)
        (check-equal? (length schemas) 2)
        (check-equal? (length configs) 2)
        (check-equal? (map poo-flow-module-option-validation-receipt-code receipts)
                      '(ok ok))))
    (poo-flow-test-case "inline imports join activation closure and workflow receipts"
      (let* ((child-task
              (make-task-family-descriptor 'inline-job
                                           'inline-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (child
              (make-poo-flow-module-descriptor
               'child
               '()
               (make-task-family-registry 'child-tasks (list child-task))
               (make-flow-declaration-registry 'child-flows '())
               '((layer . "child"))))
             (interface
              (poo-flow-module-interface
               "RootProfile"
               (.o surface: (poo-flow-string-default "root"))
               '((owner . "poo-flow"))))
             (root
              (poo-flow-modules
               interface
               (.o id: 'root
                   imports:
                   (poo-flow-imports
                    (poo-flow-import ":poo-flow/modules/root#child" child))
                   config: (.o surface: "root")
                   flags: '(+root)
                   depth: (cons 10 10)
                   hooks: '((before-init . (root-hook)))
                   extensions: (poo-flow-extensions 'root-extension)
                   scripts: (list 'root-script))))
             (activation (activate-poo-flow-modules (list root)))
             (catalog (pooFlowModuleCatalog root))
             (eval-result (poo-flow-eval-modules catalog 'root '("runtime-hook")))
             (evaluation (poo-flow-module-evaluate root))
             (presentation (poo-flow-module-system-presentation
                            catalog
                            'root
                            '("runtime-hook"))))
        (check-equal? (poo-flow-module-names
                       (poo-flow-module-activation-modules activation))
                      '(root child))
        (check-equal? (task-family-name
                       (task-family-for-kind-in
                        (poo-flow-module-activation-task-registry activation)
                        'inline-job))
                      'inline-job)
        (check-equal? (.ref eval-result 'module-count) 2)
        (check-equal? (.ref eval-result 'hook-count) 1)
        (check-equal? (.ref evaluation 'init-module-ids) '(child root))
        (check-equal? (poo-flow-module-value-catalog-active? catalog 'root '+root) #t)
        (check-equal? (poo-flow-module-value-catalog-active? catalog 'root '+missing) #f)
        (check-equal? (.ref eval-result 'extension-count) 1)
        (check-equal? (poo-flow-module-group root) poo-flow-brand-group)
        (check-equal? (.ref eval-result 'brand-name) poo-flow-brand-name)
        (check-equal? (.ref eval-result 'scheme-owner)
                      poo-flow-scheme-owner)
        (check-equal? (.ref presentation 'kind)
                      poo-flow-module-system-presentation-kind)
        (check-equal? (.ref presentation 'brand-name) poo-flow-brand-name)
        (check-equal? (.ref presentation 'import-graph-owner)
                      "poo-flow-module-system")
        (check-equal? (.ref presentation 'runtime-capability-projection-kind)
                      "poo-flow.modules.runtime-capability-projection.v1")
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
