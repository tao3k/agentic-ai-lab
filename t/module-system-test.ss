;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system tests cover descriptor activation, not loading.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 test-error
                 test-suite)
        (only-in :clan/poo/object .o .ref)
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :yuanxu/module-system/catalog/objects)

(export module-system-test)

;;; Module activation failures are captured as structured values so tests can
;;; assert missing-import payloads directly.
;; : (-> Thunk Value)
(def (capture-module-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; This suite anchors descriptor activation as the canonical module-system
;;; contract for higher-level user interface tests.
;; : TestSuite
(def module-system-test
  (test-suite "agentic-ai-lab module system"
    (yuanxu-test-case "activates module descriptor registries into run config"
      (let* ((task-descriptor
              (make-task-family-descriptor 'remote-job
                                           'remote-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (flow-descriptor
              (make-flow-declaration-descriptor 'remote-flow
                                                'remote
                                                'linear-dag
                                                'extension))
             (module
              (make-agentic-ai-lab-module-descriptor
               'remote-runtime
               '()
               (make-task-family-registry 'remote-runtime-tasks
                                          (list task-descriptor))
               (make-flow-declaration-registry 'remote-runtime-flows
                                               (list flow-descriptor))
               (list (cons 'source 'test-module))))
             (activation (activate-agentic-ai-lab-modules (list module)))
             (config (agentic-ai-lab-module-activation->run-config
                      'with-remote-runtime
                      (make-local-eager-strategy)
                      (make-request-only-adapter)
                      activation)))
        (check-equal? (agentic-ai-lab-module-descriptor? module) #t)
        (check-equal? (agentic-ai-lab-module-name module) 'remote-runtime)
        (check-equal? (cdr (assoc 'agentic-ai-lab-modules
                                  (agentic-ai-lab-module-activation-options activation)))
                      '(remote-runtime))
        (check-equal? (task-family-name
                       (task-family-for-kind-in
                        (run-config-task-registry config)
                        'remote-job))
                      'remote-job)
        (check-equal? (flow-declaration-name
                       (flow-declaration-for-kind-in
                        (run-config-flow-registry config)
                        'remote))
                      'remote-flow)))
    (yuanxu-test-case "rejects missing module imports before activation"
      (let* ((module (make-empty-agentic-ai-lab-module-descriptor
                      'feature
                      '(foundation)
                      '()))
             (failure (capture-module-failure
                       (lambda ()
                         (activate-agentic-ai-lab-modules (list module)))))
             (missing (cdr (assoc 'missing
                                  (execution-failure-detail failure)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'module-system)
        (check-equal? (execution-failure-code failure) 'missing-module-imports)
        (check-equal? (cdr (assoc 'module (car missing))) 'feature)
        (check-equal? (cdr (assoc 'import (car missing))) 'foundation)))
    (yuanxu-test-case "resolves named imports through the closure name index"
      (let ((foundation
             (make-empty-agentic-ai-lab-module-descriptor 'foundation '() '()))
            (feature
             (make-empty-agentic-ai-lab-module-descriptor
              'feature
              '(foundation)
              '())))
        (check-equal?
         (agentic-ai-lab-module-missing-imports (list feature foundation))
         '())))
    (yuanxu-test-case "module closure admits shared inline imports once"
      (let* ((shared
              (make-empty-agentic-ai-lab-module-descriptor 'shared '() '()))
             (left
              (make-empty-agentic-ai-lab-module-descriptor
               'left
               (list shared)
               '()))
             (right
              (make-empty-agentic-ai-lab-module-descriptor
               'right
               (list shared)
               '()))
             (root
              (make-empty-agentic-ai-lab-module-descriptor
               'root
               (list left right)
               '())))
        (check-equal?
         (agentic-ai-lab-module-names (agentic-ai-lab-module-closure (list root)))
         '(root left shared right))))
    (yuanxu-test-case "normalizes source refs as inspectable metadata"
      (let* ((local (make-yuanxu-module-local-source "modules/remote-runtime.ss"))
             (package (make-yuanxu-module-package-source 'remote-runtime))
             (standard-library
              (make-yuanxu-module-standard-library-source 'kernel-profile))
             (registry (make-yuanxu-module-registry-source 'kernel-profile))
             (generated (make-yuanxu-module-generated-source 'generated-runtime))
             (custom-entrypoint
              (yuanxu-module-custom-interface-entrypoint "./custom/my-module"))
             (custom
              (make-yuanxu-module-custom-interface-source "./custom/my-module"))
             (custom-metadata
              (yuanxu-module-source-ref-metadata custom))
             (local-shape (yuanxu-module-source-ref->alist local)))
        (check-equal? (yuanxu-module-source-ref? local) #t)
        (check-equal? (yuanxu-module-source-ref-kind package) 'package)
        (check-equal? (yuanxu-module-source-ref-kind standard-library)
                      'standard-library)
        (check-equal? (cdr (assoc 'library
                                  (yuanxu-module-source-ref-metadata
                                   standard-library)))
                      'standard)
        (check-equal? (yuanxu-module-source-ref-value registry) 'kernel-profile)
        (check-equal? (yuanxu-module-source-ref=? generated
                                               (make-yuanxu-module-generated-source
                                                'generated-runtime))
                      #t)
        (check-equal? (cdr (assoc 'kind local-shape)) 'local)
        (check-equal? (cdr (assoc 'value local-shape))
                      "modules/remote-runtime.ss")
        (check-equal? custom-entrypoint
                      "./custom/my-module/interface.ss")
        (check-equal? (yuanxu-module-source-ref-kind custom) 'local)
        (check-equal? (yuanxu-module-source-ref-value custom)
                      "./custom/my-module/interface.ss")
        (check-equal? (cdr (assoc 'entrypoint custom-metadata))
                      "./custom/my-module/interface.ss")))
    (yuanxu-test-case "macro syntax expands to the same descriptor contract"
      (let* ((task-descriptor
              (make-task-family-descriptor 'macro-job
                                           'macro-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (flow-descriptor
              (make-flow-declaration-descriptor 'macro-flow
                                                'macro
                                                'linear-dag
                                                'extension))
             (module
              (agentic-ai-lab-module macro-runtime
                (imports foundation)
                (tasks task-descriptor)
                (flows flow-descriptor)
                (options (cons 'source 'macro-test)))))
        (check-equal? (agentic-ai-lab-module-name module) 'macro-runtime)
        (check-equal? (yuanxu-module-imports module) '(foundation))
        (check-equal? (task-family-name (car (agentic-ai-lab-module-task-descriptors module)))
                      'macro-job)
        (check-equal? (flow-declaration-kind
                       (car (agentic-ai-lab-module-flow-descriptors module)))
                      'macro)
        (check-equal? (cdr (assoc 'source (agentic-ai-lab-module-options module)))
                      'macro-test)))
    (yuanxu-test-case "doctor reports duplicate and empty module diagnostics"
      (let* ((task-a (make-task-family-descriptor 'dup-job
                                                  'dup-job
                                                  'adapter
                                                  'rust-or-external-runtime
                                                  'submit))
             (task-b (make-task-family-descriptor 'dup-job
                                                  'dup-job
                                                  'adapter
                                                  'rust-or-external-runtime
                                                  'submit))
             (flow-a (make-flow-declaration-descriptor 'dup-flow-a
                                                       'dup-flow
                                                       'linear-dag
                                                       'extension))
             (flow-b (make-flow-declaration-descriptor 'dup-flow-b
                                                       'dup-flow
                                                       'linear-dag
                                                       'extension))
             (foundation
              (make-agentic-ai-lab-module-descriptor
               'foundation
               '()
               (make-task-family-registry 'foundation-tasks
                                          (list task-a task-b))
               (make-flow-declaration-registry 'foundation-flows
                                               (list flow-a flow-b))
               (list (cons 'source 'first)
                     (cons 'source 'second))))
             (empty (make-empty-agentic-ai-lab-module-descriptor
                     'empty
                     '(foundation)
                     '()))
             (report (agentic-ai-lab-module-doctor (list foundation empty)))
             (shape (agentic-ai-lab-module-doctor-report->alist report)))
        (check-equal? (yuanxu-module-doctor-ok? report) #f)
        (check-equal? (yuanxu-module-doctor-report-status report) 'warning)
        (check-equal? (length (yuanxu-module-doctor-report-diagnostics report)) 4)
        (check-equal? (cdr (assoc 'modules shape)) '(foundation empty))
        (check-equal? (yuanxu-module-diagnostic-code
                       (car (yuanxu-module-doctor-report-diagnostics report)))
                      'duplicate-task-family)))
    (yuanxu-test-case "resolves catalog source refs before doctor and activation"
      (let* ((source (make-yuanxu-module-generated-source 'remote-runtime))
             (task-descriptor
              (make-task-family-descriptor 'catalog-job
                                           'catalog-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (module
              (make-agentic-ai-lab-module-descriptor
               'remote-runtime
               '()
               (make-task-family-registry 'catalog-tasks
                                          (list task-descriptor))
               (make-flow-declaration-registry 'catalog-flows '())
               (list (cons 'source source))))
             (entry (make-yuanxu-module-catalog-entry source module))
             (catalog (make-yuanxu-module-catalog 'test-catalog (list entry)))
             (doctor (agentic-ai-lab-module-resolve-doctor catalog (list source)))
             (activation (agentic-ai-lab-module-resolve-and-activate catalog (list source)))
             (catalog-shape (yuanxu-module-catalog->alist catalog)))
        (check-equal? (yuanxu-module-catalog? catalog) #t)
        (check-equal? (cdr (assoc 'module (yuanxu-module-catalog-entry->alist entry)))
                      'remote-runtime)
        (check-equal? (yuanxu-module-doctor-report-status doctor) 'ok)
        (check-equal? (task-family-name
                       (task-family-for-kind-in
                        (agentic-ai-lab-module-activation-task-registry activation)
                        'catalog-job))
                      'catalog-job)
        (check-equal? (cdr (assoc 'name catalog-shape)) 'test-catalog)))
    (yuanxu-test-case "raises typed failure for missing catalog sources"
      (let* ((catalog (make-yuanxu-module-catalog 'empty-catalog '()))
             (source (make-yuanxu-module-local-source "missing.ss"))
             (failure (capture-module-failure
                       (lambda ()
                         (resolve-agentic-ai-lab-module-source catalog source))))
             (detail (execution-failure-detail failure))
             (source-shape (cdr (assoc 'source detail))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'module-system)
        (check-equal? (execution-failure-code failure) 'missing-module-source)
        (check-equal? (cdr (assoc 'catalog detail)) 'empty-catalog)
        (check-equal? (cdr (assoc 'value source-shape)) "missing.ss")))))
