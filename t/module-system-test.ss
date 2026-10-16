;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system tests cover descriptor activation, not loading.

(import (only-in :core/observability/testing-case poo-flow-test-case)
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
        :poo-flow/modules/workflow/control-plane/api
        :poo-flow/modules/module-authoring/module-descriptor
        :poo-flow/modules/workflow/scenario/configuration/module-diagnostics
        :core/module-system/source/imports
        :core/module-system/source/objects
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :core/module-system/catalog/objects)

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
  (test-suite "poo-flow module system"
    (poo-flow-test-case "activates module descriptor registries into run config"
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
              (make-poo-flow-module-descriptor
               'remote-runtime
               '()
               (make-task-family-registry 'remote-runtime-tasks
                                          (list task-descriptor))
               (make-flow-declaration-registry 'remote-runtime-flows
                                               (list flow-descriptor))
               (list (cons 'source 'test-module))))
             (activation (activate-poo-flow-modules (list module)))
             (config (poo-flow-module-activation->run-config
                      'with-remote-runtime
                      (make-local-eager-strategy)
                      (make-request-only-adapter)
                      activation)))
        (check-equal? (poo-flow-module-descriptor? module) #t)
        (check-equal? (poo-flow-module-name module) 'remote-runtime)
        (check-equal? (cdr (assoc 'poo-flow-modules
                                  (poo-flow-module-activation-options activation)))
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
    (poo-flow-test-case "rejects missing module imports before activation"
      (let* ((module (make-empty-poo-flow-module-descriptor
                      'feature
                      '(foundation)
                      '()))
             (failure (capture-module-failure
                       (lambda ()
                         (activate-poo-flow-modules (list module)))))
             (missing (cdr (assoc 'missing
                                  (execution-failure-detail failure)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'module-system)
        (check-equal? (execution-failure-code failure) 'missing-module-imports)
        (check-equal? (cdr (assoc 'module (car missing))) 'feature)
        (check-equal? (cdr (assoc 'import (car missing))) 'foundation)))
    (poo-flow-test-case "resolves named imports through the closure name index"
      (let ((foundation
             (make-empty-poo-flow-module-descriptor 'foundation '() '()))
            (feature
             (make-empty-poo-flow-module-descriptor
              'feature
              '(foundation)
              '())))
        (check-equal?
         (poo-flow-module-missing-imports (list feature foundation))
         '())))
    (poo-flow-test-case "module closure admits shared inline imports once"
      (let* ((shared
              (make-empty-poo-flow-module-descriptor 'shared '() '()))
             (left
              (make-empty-poo-flow-module-descriptor
               'left
               (list shared)
               '()))
             (right
              (make-empty-poo-flow-module-descriptor
               'right
               (list shared)
               '()))
             (root
              (make-empty-poo-flow-module-descriptor
               'root
               (list left right)
               '())))
        (check-equal?
         (poo-flow-module-names (poo-flow-module-closure (list root)))
         '(root left shared right))))
    (poo-flow-test-case "normalizes source refs as inspectable metadata"
      (let* ((local (make-poo-flow-module-local-source "modules/remote-runtime.ss"))
             (package (make-poo-flow-module-package-source 'remote-runtime))
             (standard-library
              (make-poo-flow-module-standard-library-source 'kernel-profile))
             (registry (make-poo-flow-module-registry-source 'kernel-profile))
             (generated (make-poo-flow-module-generated-source 'generated-runtime))
             (custom-entrypoint
              (poo-flow-module-custom-interface-entrypoint "./custom/my-module"))
             (custom
              (make-poo-flow-module-custom-interface-source "./custom/my-module"))
             (custom-metadata
              (poo-flow-module-source-ref-metadata custom))
             (local-shape (poo-flow-module-source-ref->alist local)))
        (check-equal? (poo-flow-module-source-ref? local) #t)
        (check-equal? (poo-flow-module-source-ref-kind package) 'package)
        (check-equal? (poo-flow-module-source-ref-kind standard-library)
                      'standard-library)
        (check-equal? (cdr (assoc 'library
                                  (poo-flow-module-source-ref-metadata
                                   standard-library)))
                      'standard)
        (check-equal? (poo-flow-module-source-ref-value registry) 'kernel-profile)
        (check-equal? (poo-flow-module-source-ref=? generated
                                               (make-poo-flow-module-generated-source
                                                'generated-runtime))
                      #t)
        (check-equal? (cdr (assoc 'kind local-shape)) 'local)
        (check-equal? (cdr (assoc 'value local-shape))
                      "modules/remote-runtime.ss")
        (check-equal? custom-entrypoint
                      "./custom/my-module/interface.ss")
        (check-equal? (poo-flow-module-source-ref-kind custom) 'local)
        (check-equal? (poo-flow-module-source-ref-value custom)
                      "./custom/my-module/interface.ss")
        (check-equal? (cdr (assoc 'entrypoint custom-metadata))
                      "./custom/my-module/interface.ss")))
    (poo-flow-test-case "macro syntax expands to the same descriptor contract"
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
              (poo-flow-module macro-runtime
                (imports foundation)
                (tasks task-descriptor)
                (flows flow-descriptor)
                (options (cons 'source 'macro-test)))))
        (check-equal? (poo-flow-module-name module) 'macro-runtime)
        (check-equal? (poo-flow-module-imports module) '(foundation))
        (check-equal? (task-family-name (car (poo-flow-module-task-descriptors module)))
                      'macro-job)
        (check-equal? (flow-declaration-kind
                       (car (poo-flow-module-flow-descriptors module)))
                      'macro)
        (check-equal? (cdr (assoc 'source (poo-flow-module-options module)))
                      'macro-test)))
    (poo-flow-test-case "doctor reports duplicate and empty module diagnostics"
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
              (make-poo-flow-module-descriptor
               'foundation
               '()
               (make-task-family-registry 'foundation-tasks
                                          (list task-a task-b))
               (make-flow-declaration-registry 'foundation-flows
                                               (list flow-a flow-b))
               (list (cons 'source 'first)
                     (cons 'source 'second))))
             (empty (make-empty-poo-flow-module-descriptor
                     'empty
                     '(foundation)
                     '()))
             (report (poo-flow-module-doctor (list foundation empty)))
             (shape (poo-flow-module-doctor-report->alist report)))
        (check-equal? (poo-flow-module-doctor-ok? report) #f)
        (check-equal? (poo-flow-module-doctor-report-status report) 'warning)
        (check-equal? (length (poo-flow-module-doctor-report-diagnostics report)) 4)
        (check-equal? (cdr (assoc 'modules shape)) '(foundation empty))
        (check-equal? (poo-flow-module-diagnostic-code
                       (car (poo-flow-module-doctor-report-diagnostics report)))
                      'duplicate-task-family)))
    (poo-flow-test-case "resolves catalog source refs before doctor and activation"
      (let* ((source (make-poo-flow-module-generated-source 'remote-runtime))
             (task-descriptor
              (make-task-family-descriptor 'catalog-job
                                           'catalog-job
                                           'adapter
                                           'rust-or-external-runtime
                                           'submit))
             (module
              (make-poo-flow-module-descriptor
               'remote-runtime
               '()
               (make-task-family-registry 'catalog-tasks
                                          (list task-descriptor))
               (make-flow-declaration-registry 'catalog-flows '())
               (list (cons 'source source))))
             (entry (make-poo-flow-module-catalog-entry source module))
             (catalog (make-poo-flow-module-catalog 'test-catalog (list entry)))
             (doctor (poo-flow-module-resolve-doctor catalog (list source)))
             (activation (poo-flow-module-resolve-and-activate catalog (list source)))
             (catalog-shape (poo-flow-module-catalog->alist catalog)))
        (check-equal? (poo-flow-module-catalog? catalog) #t)
        (check-equal? (cdr (assoc 'module (poo-flow-module-catalog-entry->alist entry)))
                      'remote-runtime)
        (check-equal? (poo-flow-module-doctor-report-status doctor) 'ok)
        (check-equal? (task-family-name
                       (task-family-for-kind-in
                        (poo-flow-module-activation-task-registry activation)
                        'catalog-job))
                      'catalog-job)
        (check-equal? (cdr (assoc 'name catalog-shape)) 'test-catalog)))
    (poo-flow-test-case "raises typed failure for missing catalog sources"
      (let* ((catalog (make-poo-flow-module-catalog 'empty-catalog '()))
             (source (make-poo-flow-module-local-source "missing.ss"))
             (failure (capture-module-failure
                       (lambda ()
                         (resolve-poo-flow-module-source catalog source))))
             (detail (execution-failure-detail failure))
             (source-shape (cdr (assoc 'source detail))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'module-system)
        (check-equal? (execution-failure-code failure) 'missing-module-source)
        (check-equal? (cdr (assoc 'catalog detail)) 'empty-catalog)
        (check-equal? (cdr (assoc 'value source-shape)) "missing.ss")))))
