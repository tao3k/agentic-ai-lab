;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Control-plane integration tests pin the Scheme receipt boundary.
;;; They exercise policy projection without assuming runtime side effects.

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
        :yuanxu/modules/funflow/control-plane/api
        :yuanxu/modules/funflow/store)

;;; Failure capture keeps configured-runner checks on structured values instead
;;; of rendered exception text.
;; : (-> Thunk Value)
(def (control-plane-test-capture-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;; : (forall (a) (-> [a] [a] [a]))
(def (control-plane-test-values/tail values tail)
  (let loop ((remaining-values values)
             (values-rev '()))
    (if (null? remaining-values)
      (let restore ((remaining-rev values-rev)
                    (result tail))
        (if (null? remaining-rev)
          result
          (restore (cdr remaining-rev)
                   (cons (car remaining-rev) result))))
      (loop (cdr remaining-values)
            (cons (car remaining-values) values-rev)))))

;;; This suite anchors the pure local runner path as the baseline for receipt
;;; and child-node assertions.
;; : TestSuite
(def pure-flow-test
  (test-suite "pure flow"
    (yuanxu-test-case "runs pure tasks sequentially and records receipts"
      (let* ((inc (make-pure-task 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (make-pure-task 'double (lambda (x) (* x 2)) 'number 'number))
             (flow (flow-compose 'math (list inc double) 'number 'number))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner flow 3))
             (receipt (run-result-receipt result)))
        (check-equal? (run-result-value result) 8)
        (check-equal? (receipt-flow receipt) 'math)
        (check-equal? (receipt-status receipt) 'ok)
        (check-equal? (length (receipt-children receipt)) 2)))))

;;; This suite protects the adapter boundary where external tasks become
;;; request-only runtime envelopes.
;; : TestSuite
(def adapter-request-test
  (test-suite "adapter request boundary"
    (yuanxu-test-case "lowers external tasks into adapter requests"
      (let* ((external (make-external-task 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (flow (flow-compose 'external-demo (list external) 'artifact 'artifact))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner flow 'input-artifact))
             (adapter-result (run-result-value result))
             (request (adapter-result-value adapter-result))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (receipt-task child) 'compile)
        (check-equal? (receipt-kind child) 'external)
        (check-equal? (receipt-node-id child) '(node external-demo 0 external compile))
        (check-equal? (receipt-adapter-decision child) 'request-only)
        (check-equal? (adapter-result-status adapter-result) 'requested)
        (check-equal? (execution-request-plan-id request) 'external-demo)
        (check-equal? (execution-request-node-id request)
                      '(node external-demo 0 external compile))
        (check-equal? (execution-request-frontier request)
                      '((node external-demo 0 external compile)))
        (check-equal? (execution-request-strategy request) 'local-eager)
        (check-equal? (execution-request-policy request)
                      '((strategy . local-eager)
                        (cache-policy . no-cache)
                        (failure-policy . fail-fast)
                        (capabilities pure scheme external branch graph-frontier)
                        (frontier (node external-demo 0 external compile))
                        (task-registry . default-task-families)
                        (flow-registry . default-flow-declarations)))
        (check-equal? (receipt-policy child)
                      (execution-request-policy request))))))

;;; This suite keeps Funflow-style smart constructors aligned with the lower
;;; level flow and task descriptors.
;; : TestSuite
(def funflow-api-test
  (test-suite "funflow-style flow api"
    (yuanxu-test-case "builds and runs flow-level smart constructors"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (pipeline (flow-then 'inc-then-double inc double))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner pipeline 4)))
        (check-equal? (flow-step-count pipeline) 2)
        (check-equal? (flow-input-contract pipeline) 'number)
        (check-equal? (flow-output-contract pipeline) 'number)
        (check-equal? (run-result-value result) 10)))
    (yuanxu-test-case "keeps return-flow as identity"
      (let* ((identity (return-flow 'return-number 'number))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner identity 11)))
        (check-equal? (run-result-value result) 11)))
    (yuanxu-test-case "lowers external-flow into adapter request"
      (let* ((compile (external-flow 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner compile 'input-artifact))
             (receipt (run-result-receipt result))
             (request (adapter-result-value (run-result-value result)))
             (child (car (receipt-children receipt))))
        (check-equal? (receipt-flow receipt) 'compile)
        (
         check-equal? (receipt-kind child) 'external)
        (check-equal? (receipt-node-id child) '(node compile 0 external compile))
        (check-equal? (adapter-result-status (run-result-value result)) 'requested)
        (check-equal? (execution-request-plan-id request) 'compile)
        (check-equal? (execution-request-frontier request)
                      '((node compile 0 external compile)))))))

;;; This suite exercises configured runner policy before backend runtimes see
;;; the request.
;; : TestSuite
(def configured-runner-test
  (test-suite "configured runner"
    (yuanxu-test-case "runs through request-only config"
      (let* ((compile (external-flow 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (config (make-request-only-run-config))
             (result (run-flow-with-config config compile 'input-artifact))
             (adapter-result (run-result-value result))
             (request (adapter-result-value adapter-result)))
        (check-equal? (run-config-name config) 'request-only)
        (check-equal? (run-config-runtime-owner config) 'request-only)
        (check-equal? (adapter-result-status adapter-result) 'requested)
        (check-equal? (execution-request-plan-id request) 'compile)))
    (yuanxu-test-case "submits external requests to rust adapter boundary"
      (let* ((compile (external-flow 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (config (make-rust-run-config))
             (runner (run-config->runner config))
             (result (run-flow-with-config config compile 'input-artifact))
             (adapter-result (run-result-value result))
             (envelope (adapter-result-value adapter-result))
             (request (cdr (assoc 'request envelope)))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (run-config-runtime-owner config) 'rust)
        (check-equal? (runtime-adapter-name (runner-adapter runner)) 'rust)
        (check-equal? (adapter-result-status adapter-result) 'submitted)
        (check-equal? (adapter-result-request-id adapter-result) '(rust-request compile external))
        (check-equal? (adapter-result-artifact-handle adapter-result)
                      '(rust-artifact compile (node compile 0 external compile)))
        (check-equal? (cdr (assoc 'runtime envelope)) 'rust)
        (check-equal? (execution-request-plan-id request) 'compile)
        (check-equal? (execution-request-node-id request)
                      '(node compile 0 external compile))
        (check-equal? (cdr (assoc 'policy envelope))
                      (execution-request-policy request))
        (check-equal? (receipt-adapter-decision child) 'rust)))
    (yuanxu-test-case "submits branch arms to rust adapter boundary"
      (let* ((compile (external-flow 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (put (store-flow 'put-cache 'put '((path . "target")) 'artifact 'artifact))
             (branch (flow-branch 'runtime-fanout compile put))
             (config (make-store-rust-run-config))
             (result (run-flow-with-config config branch 'input-artifact))
             (values (run-result-value result))
             (left-result (car values))
             (right-result (cadr values)))
        (check-equal? (adapter-result-status left-result) 'submitted)
        (check-equal? (adapter-result-status right-result) 'submitted)
        (check-equal? (adapter-result-request-id left-result) '(rust-request compile external))
        (check-equal? (adapter-result-request-id right-result) '(rust-request put-cache store))))
    (yuanxu-test-case "threads descriptor registries through configured execution"
      (let* ((docker (make-task-family-descriptor 'docker
                                                  'external
                                                  'adapter
                                                  'rust-or-external-runtime
                                                  'submit))
             (task-registry (make-task-family-registry
                             'configured-task-families
                             (control-plane-test-values/tail
                              task-family-descriptors
                              (list docker))))
             (flow-registry (make-flow-declaration-registry
                             'configured-flow-declarations
                             flow-declaration-descriptors))
             (task (make-task 'build-image
                              'docker
                              '(docker build)
                              'artifact
                              'artifact
                              #f))
             (flow (flow-compose 'docker-demo (list task) 'artifact 'artifact))
             (config (make-run-config 'configured-extension
                                      (make-local-eager-strategy)
                                      (make-request-only-adapter)
                                      '((runtime . request-only))
                                      task-registry
                                      flow-registry))
             (runner (run-config->runner config))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result))
             (request (adapter-result-value adapter-result))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (task-family-registry-name (run-config-task-registry config))
                      'configured-task-families)
        (check-equal? (flow-declaration-registry-name (run-config-flow-registry config))
                      'configured-flow-declarations)
        (check-equal? (run-config-registry-policy config)
                      '((task-registry . configured-task-families)
                        (flow-registry . configured-flow-declarations)))
        (check-equal? (run-config-validate-registries config flow) #t)
        (check-equal? (task-family-registry-name (runner-task-registry runner))
                      'configured-task-families)
        (check-equal? (flow-declaration-registry-name (runner-flow-registry runner))
                      'configured-flow-declarations)
        (check-equal? (adapter-result-status adapter-result) 'requested)
        (check-equal? (adapter-result-request-id adapter-result)
                      '(request build-image docker))
        (check-equal? (execution-request-kind request) 'docker)
        (check-equal? (cdr (assoc 'task-registry (execution-request-policy request)))
                      'configured-task-families)
        (check-equal? (cdr (assoc 'flow-registry (execution-request-policy request)))
                      'configured-flow-declarations)
        (check-equal? (receipt-policy child)
                      (execution-request-policy request))))
    (yuanxu-test-case "fails configured validation when task registry lacks descriptor"
      (let* ((docker-task (make-task 'build-image
                                     'docker
                                     '(docker build)
                                     'artifact
                                     'artifact
                                     #f))
             (flow (flow-compose 'missing-task-family
                                 (list docker-task)
                                 'artifact
                                 'artifact))
             (config (make-run-config 'missing-task-registry
                                      (make-local-eager-strategy)
                                      (make-request-only-adapter)
                                      '((runtime . request-only))
                                      default-task-family-registry
                                      default-flow-declaration-registry))
             (failure
              (control-plane-test-capture-failure
               (lambda ()
                 (run-config-validate-registries config flow)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'task-registry)
        (check-equal? (execution-failure-code failure) 'unknown-task-family)
        (check-equal? (cdr (assoc 'registry (execution-failure-detail failure)))
                      'default-task-families)
        (check-equal? (cdr (assoc 'kind (execution-failure-detail failure)))
                      'docker)))
    (yuanxu-test-case "fails configured validation when flow registry lacks descriptor"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (empty-flow-registry
              (make-flow-declaration-registry 'empty-flow-declarations '()))
             (config (make-run-config 'missing-flow-registry
                                      (make-local-eager-strategy)
                                      (make-request-only-adapter)
                                      '((runtime . request-only))
                                      default-task-family-registry
                                      empty-flow-registry))
             (failure
              (control-plane-test-capture-failure
               (lambda ()
                 (run-config-validate-registries config inc)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'flow-registry)
        (check-equal? (execution-failure-code failure)
                      'unknown-flow-declaration)
        (check-equal? (cdr (assoc 'registry (execution-failure-detail failure)))
                      'empty-flow-declarations)
        (check-equal? (cdr (assoc 'kind (execution-failure-detail failure)))
                      'task)))))

;;; This suite protects branch flow receipt shape for parallel frontier
;;; construction.
;; : TestSuite
(def branch-flow-test
  (test-suite "branch flow"
    (yuanxu-test-case "runs pure branches locally"
      (let* ((left (pure-flow 'left (lambda (x) (+ x 1)) 'number 'number))
             (right (pure-flow 'right (lambda (x) (* x 2)) 'number 'number))
             (branch (flow-branch 'local-fanout left right))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner branch 3))
             (receipt (run-result-receipt result)))
        (check-equal? (run-result-value result) '(4 6))
        (check-equal? (length (receipt-children receipt)) 3)
        (check-equal? (receipt-kind (caddr (receipt-children receipt))) 'branch)
        (check-equal? (receipt-output (caddr (receipt-children receipt))) '(4 6))))))

;;; This suite keeps execution-plan lowering visible as data for scheduler and
;;; observability checks.
;; : TestSuite
(def execution-plan-test
  (test-suite "execution plan"
    (yuanxu-test-case "strategy lowers flows into named plan nodes"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (pipeline (flow-then 'inc-then-double inc double))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (plan (runner-plan runner pipeline))
             (nodes (execution-plan-nodes plan))
             (first-node (car nodes))
             (second-node (cadr nodes)))
        (check-equal? (execution-plan-flow-name plan) 'inc-then-double)
        (check-equal? (plan-node-count plan) 2)
        (check-equal? (plan-node-id first-node) '(node inc-then-double 0 pure inc))
        (check-equal? (plan-node-kind first-node) 'pure)
        (check-equal? (plan-node-name first-node) 'inc)
        (check-equal? (plan-node-dependencies first-node) '())
        (check-equal? (plan-node-id second-node) '(node inc-then-double 1 scheme double))
        (check-equal? (plan-node-kind second-node) 'scheme)
        (check-equal? (plan-node-name second-node) 'double)
        (check-equal? (plan-node-dependencies second-node)
                      '((node inc-then-double 0 pure inc)))))
    (yuanxu-test-case "exposes dependency graph inspection helpers"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (label (pure-flow 'label (lambda (x) x) 'number 'number))
             (pipeline (flow-then 'graph-demo
                                  (flow-then 'inc-then-double inc double)
                                  label))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (plan (runner-plan runner pipeline))
             (nodes (execution-plan-nodes plan))
             (first-node (car nodes))
             (second-node (cadr nodes))
             (third-node (caddr nodes)))
        (check-equal? (execution-plan-node-ids plan)
                      '((node graph-demo 0 pure inc)
                        (node graph-demo 1 scheme double)
                        (node graph-demo 2 pure label)))
        (check-equal? (execution-plan-dependency-edges plan)
                      '(((node graph-demo 0 pure inc)
                         (node graph-demo 1 scheme double))
                        ((node graph-demo 1 scheme double)
                         (node graph-demo 2 pure label))))
        (check-equal? (map plan-node-id (execution-plan-root-nodes plan))
                      '((node graph-demo 0 pure inc)))
        (check-equal? (execution-plan-root-node-ids plan)
                      '((node graph-demo 0 pure inc)))
        (check-equal? (map plan-node-id (execution-plan-terminal-nodes plan))
                      '((node graph-demo 2 pure label)))
        (check-equal? (execution-plan-terminal-node-ids plan)
                      '((node graph-demo 2 pure label)))
        (check-equal? (plan-node-root? first-node) #t)
        (check-equal? (plan-node-root? second-node) #f)
        (check-equal? (plan-node-depends-on? second-node (plan-node-id first-node)) #t)
        (check-equal? (plan-node-depends-on? third-node (plan-node-id first-node)) #f)))
    (yuanxu-test-case "lowers branch flows into a DAG"
      (let* ((left (pure-flow 'left (lambda (x) (+ x 1)) 'number 'number))
             (right (pure-flow 'right (lambda (x) (* x 2)) 'number 'number))
             (branch (flow-branch 'fanout left right))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (plan (runner-plan runner branch))
             (nodes (execution-plan-nodes plan))
             (left-node (car nodes))
             (right-node (cadr nodes))
             (join-node (caddr nodes)))
        (check-equal? (flow-step-count branch) 1)
        (check-equal? (plan-node-count plan) 3)
        (check-equal? (execution-plan-node-ids plan)
                      '((node fanout 0 branch-left left)
                        (node fanout 1 branch-right right)
                        (node fanout 2 branch fanout)))
        (check-equal? (execution-plan-dependency-edges plan)
                      '(((node fanout 0 branch-left left)
                         (node fanout 2 branch fanout))
                        ((node fanout 1 branch-right right)
                         (node fanout 2 branch fanout))))
        (check-equal? (map plan-node-id (execution-plan-root-nodes plan))
                      '((node fanout 0 branch-left left)
                        (node fanout 1 branch-right right)))
        (check-equal? (map plan-node-id (execution-plan-terminal-nodes plan))
                      '((node fanout 2 branch fanout)))
        (check-equal? (plan-node-root? left-node) #t)
        (check-equal? (plan-node-root? right-node) #t)
        (check-equal? (plan-node-dependencies join-node)
                      '((node fanout 0 branch-left left)
                        (node fanout 1 branch-right right)))))))

;;; This suite guards strategy frontier behavior across eager and graph-aware
;;; scheduling paths.
;; : TestSuite
(def strategy-frontier-test
  (test-suite "strategy frontier policy"
    (yuanxu-test-case "selects ready nodes from completed dependency ids"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (label (pure-flow 'label (lambda (x) x) 'number 'number))
             (pipeline (flow-then 'frontier-demo
                                  (flow-then 'inc-then-double inc double)
                                  label))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (strategy (runner-strategy runner))
             (plan (runner-plan runner pipeline))
             (first-complete '((node frontier-demo 0 pure inc)))
             (second-complete '((node frontier-demo 0 pure inc)
                                (node frontier-demo 1 scheme double)))
             (policy (strategy-execution-policy strategy second-complete))
             (result (runner-run runner pipeline 2))
             (receipt (run-result-receipt result))
             (children (receipt-children receipt)))
        (check-equal? (strategy-can-select-frontier? strategy) #t)
        (check-equal? (execution-policy-strategy policy) 'local-eager)
        (check-equal? (execution-policy-allows? policy 'external) #t)
        (check-equal? (execution-policy-cache-enabled? policy) #f)
        (check-equal? (cdr (assoc 'frontier (execution-policy->alist policy)))
                      second-complete)
        (check-equal? (execution-plan-ready-node-ids plan '())
                      '((node frontier-demo 0 pure inc)))
        (check-equal? (execution-plan-ready-node-ids plan first-complete)
                      '((node frontier-demo 1 scheme double)))
        (check-equal? (map plan-node-id
                           (strategy-ready-frontier strategy plan second-complete))
                      '((node frontier-demo 2 pure label)))
        (check-equal? (runner-ready-frontier-ids runner pipeline second-complete)
                      '((node frontier-demo 2 pure label)))
        (check-equal? (runner-ready-frontier-ids runner pipeline
                                                (execution-plan-node-ids plan))
                      '())
        (check-equal? (receipt-frontier receipt)
                      '((node frontier-demo 0 pure inc)))
        (check-equal? (receipt-frontier (car children))
                      '((node frontier-demo 0 pure inc)))
        (check-equal? (receipt-frontier (cadr children))
                      '((node frontier-demo 1 scheme double)))
        (check-equal? (receipt-frontier (caddr children))
                      '((node frontier-demo 2 pure label)))))))

;;; This suite protects audit receipts used to explain policy and execution
;;; decisions.
;; : TestSuite
(def receipt-audit-test
  (test-suite "receipt audit summary"
    (yuanxu-test-case "exports replay events in execution order"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (label (pure-flow 'label (lambda (x) x) 'number 'number))
             (pipeline (flow-then 'audit-demo
                                  (flow-then 'inc-then-double inc double)
                                  label))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (plan (runner-plan runner pipeline))
             (receipt (run-result-receipt (runner-run runner pipeline 2)))
             (summary (receipt->run-summary receipt))
             (report (validate-replay-report plan receipt))
             (runner-report (runner-run-replay-report runner pipeline 2))
             (events (cdr (assoc 'events summary)))
             (root-event (car events))
             (first-event (cadr events))
             (third-event (cadddr events)))
        (check-equal? (cdr (assoc 'event-count summary)) 4)
        (check-equal? (receipt-event-count receipt) 4)
        (check-equal? (replay-report-valid? report) #t)
        (check-equal? (replay-report-status report) 'valid)
        (check-equal? (replay-report-reason-count report) 0)
        (check-equal? (replay-report-expected-node-ids report)
                      '((node audit-demo 0 pure inc)
                        (node audit-demo 1 scheme double)
                        (node audit-demo 2 pure label)))
        (check-equal? (replay-report-observed-node-ids report)
                      (replay-report-expected-node-ids report))
        (check-equal? (replay-report-valid? runner-report) #t)
        (check-equal? (cdr (assoc 'adapter-request-count summary)) 0)
        (check-equal? (receipt-adapter-request-count receipt) 0)
        (check-equal? (cdr (assoc 'strategy
                                  (cdr (assoc 'policy root-event))))
                      'local-eager)
        (check-equal? (cdr (assoc 'path root-event)) '())
        (check-equal? (cdr (assoc 'path first-event)) '(0))
        (check-equal? (cdr (assoc 'node-id first-event))
                      '(node audit-demo 0 pure inc))
        (check-equal? (cdr (assoc 'path third-event)) '(2))
        (check-equal? (cdr (assoc 'frontier root-event))
                      '((node audit-demo 0 pure inc)))
        (check-equal? (cdr (assoc 'task third-event)) 'label)))
    (yuanxu-test-case "counts adapter request receipts"
      (let* ((external (external-flow 'compile 'rust-build '((crate . "agentic-ai-lab")) 'artifact 'artifact))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (receipt (run-result-receipt (runner-run runner external 'input-artifact)))
             (summary (receipt->run-summary receipt))
             (events (cdr (assoc 'events summary)))
             (child-event (cadr events)))
        (check-equal? (cdr (assoc 'event-count summary)) 2)
        (check-equal? (cdr (assoc 'adapter-request-count summary)) 1)
        (check-equal? (cdr (assoc 'request-id child-event))
                      '(request compile external))
        (check-equal? (cdr (assoc 'adapter-decision child-event)) 'request-only)))))

;;; This suite keeps cache strategy semantics explicit in receipts rather than
;;; hidden in runner state.
;; : TestSuite
(def strategy-cache-test
  (test-suite "strategy cache policy"
    (yuanxu-test-case "records cache bypass for no-cache task receipts"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner inc 5))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (run-result-value result) 6)
        (check-equal? (receipt-cache child) '(cache-bypass inc pure))))
    (yuanxu-test-case "records cache intent in task receipts"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (runner (make-runner (make-cached-local-eager-strategy)
                                  (make-request-only-adapter)))
             (result (runner-run runner inc 5))
             (receipt (run-result-receipt result))
             (child (car (receipt-children receipt))))
        (check-equal? (run-result-value result) 6)
        (check-equal? (receipt-cache receipt) 'no-cache)
        (check-equal? (cdr (assoc 'cache-policy (receipt-policy child)))
                      'cache-output)
        (check-equal? (receipt-cache child) '(cache-miss inc pure 5 6))))))

;;; This suite covers store cache behavior as a control-plane contract before
;;; an external store backend is involved.
;; : TestSuite
(def store-cache-semantics-test
  (test-suite "store cache semantics"
    (yuanxu-test-case "exposes store operation semantics"
      (let ((put (make-store-task 'put-cache 'put '((path . "target")) 'artifact 'artifact))
            (get (make-store-task 'get-cache 'get 'cache-handle 'artifact 'artifact)))
        (check-equal? (task-store-operation put) 'put)
        (check-equal? (task-store-payload get) 'cache-handle)
        (check-equal? (task-store-put? put) #t)
        (check-equal? (task-store-get? get) #t)))
    (yuanxu-test-case "routes store put through the store adapter slot"
      (let* ((put (store-flow 'put-cache 'put '((path . "target")) 'artifact 'artifact))
             (result (run-flow-with-config (make-store-run-config)
                                           put
                                           'input-artifact))
             (adapter-result (run-result-value result))
             (request (adapter-result-value adapter-result))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (adapter-result-status adapter-result) 'requested)
        (check-equal? (adapter-result-request-id adapter-result)
                      '(request put-cache store))
        (check-equal? (execution-request-request request)
                      '(store put ((path . "target"))))
        (check-equal? (receipt-cache child)
                      '(adapter-result
                        put-cache
                        store
                        store-put
                        requested
                        (request put-cache store)
                        #f))))
    (yuanxu-test-case "routes store get through the store adapter slot"
      (let* ((get (store-flow 'get-cache 'get 'cache-handle 'artifact 'artifact))
             (result (run-flow-with-config (make-store-run-config)
                                           get
                                           'input-artifact))
             (adapter-result (run-result-value result))
             (child (car (receipt-children (run-result-receipt result)))))
        (check-equal? (adapter-result-status adapter-result) 'requested)
        (check-equal? (adapter-result-request-id adapter-result)
                      '(store-get cache-handle))
        (check-equal? (adapter-result-value adapter-result) #f)
        (check-equal? (adapter-result-artifact-handle adapter-result) 'cache-handle)
        (check-equal? (receipt-cache child)
                      '(adapter-result
                        get-cache
                        store
                        store-get
                        requested
                        (store-get cache-handle)
                        cache-handle))))))

;;; Policy checks run as their own root leaf test; this file keeps the
;;; control-plane receipt boundary focused.
(export control-plane-test)

(def control-plane-test
  (test-suite "control plane"
    pure-flow-test
    adapter-request-test
    funflow-api-test
    configured-runner-test
    branch-flow-test
    execution-plan-test
    strategy-frontier-test
    receipt-audit-test
    strategy-cache-test
    store-cache-semantics-test))
