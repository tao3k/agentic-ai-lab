;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module owner contracts stay separate from activation tests.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/module-system/authoring/syntax
        :agentic-ai-lab/modules/module-authoring/module-option-projection
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        :yuanxu/module-system/catalog/values
        :yuanxu/module-system/projection/option-objects
        :yuanxu/module-system/projection/option-validation
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :yuanxu/module-system/funs
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :yuanxu/module-system/catalog/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface)

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
        "yuanxu/module-system/interface.ss"
        (lambda (port)
          (source-port-has-module-prefix?
           port
           ":agentic-ai-lab/modules/"
           ":yuanxu/")))
       #f)
      (check-equal?
       (source-datum-has-module-prefix?
        '(import :agentic-ai-lab/modules/funflow/interface)
        ":agentic-ai-lab/modules/" ":yuanxu/")
       #t))
    (yuanxu-test-case "builds Marlin-style interface config descriptors"
      (let* ((interface
              (yuanxu-module-interface
               "WorkspaceProfile"
               (.o workspace-root: (yuanxu-string-default "workspace")
                   surface: (yuanxu-string-constant "agentic-ai-lab"))
               '((owner . "agentic-ai-lab") (surface . "module-system"))))
             (source (yuanxu-local-source "modules/workspace.ss"))
             (derived-interface
              (.o (:: @ interface)
                  schemas: (.o derived-only:
                                (yuanxu-string-constant "derived"))))
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
        (check-equal? (map yuanxu-module-option-validation-receipt-code receipts)
                      '(ok ok))))
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
               (.o surface: (yuanxu-string-default "root"))
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
