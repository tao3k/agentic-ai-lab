;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: descriptor tests cover facade-level task family and accessors.
;;; Invariant: backend profile and bridge envelope behavior live in sibling tests.

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
        :poo-flow/modules/workflow/control-plane/api
        :poo-flow/modules/agent-sandbox/api
        :poo-flow/modules/agent-sandbox/nono)

(export agent-sandbox-descriptor-test)

;; : (-> Value Alist AdapterResult)
(def (runtime-result value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id '(runtime agent-sandbox-test))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((runtime . agent-sandbox-descriptor-test)))))

;; : (-> ExecutionRequest Alist)
(def (request-config request)
  (cadr (execution-request-request request)))

;;; This suite protects descriptor defaults before backend-specific modules add
;;; their own profile or runtime policy.
;; : TestSuite
(def agent-sandbox-descriptor-test
  (test-suite "agent sandbox task descriptor"
    (poo-flow-test-case "declares adapter-routed task family policy"
      (let* ((registry (make-agent-sandbox-task-family-registry))
             (task (make-agent-sandbox-task
                    'agent-run
                    'nono
                    'local-profile
                    "opencode"
                    '("--print" "hello")
                    '()
                    "/workspace"
                    '()
                    '((mode . blocked))
                    '()
                    '((timeout-ms . 30000))
                    'artifact
                    '((agent . opencode))
                    'unit
                    'artifact)))
        (check-equal? (task-family-name agent-sandbox-task-family-descriptor)
                      'agent-sandbox)
        (check-equal? (task-family-capability agent-sandbox-task-family-descriptor)
                      'agent-sandbox)
        (check-equal? (task-family-route agent-sandbox-task-family-descriptor)
                      'adapter)
        (check-equal? (task-family-runtime-owner agent-sandbox-task-family-descriptor)
                      'marlin-or-external-runtime)
        (check-equal? (task-capability-in registry task) 'agent-sandbox)
        (check-equal? (task-route-in registry task) 'adapter)
        (check-equal? (task-adapter-operation-in registry task) 'submit)))
    (poo-flow-test-case "adds explicit strategy and adapter capability"
      (let ((strategy (make-agent-sandbox-enabled-strategy))
            (adapter (make-agent-sandbox-enabled-adapter
                      (make-request-only-adapter))))
        (check-equal? (and (memq 'agent-sandbox
                                 (strategy-capabilities strategy))
                           #t)
                      #t)
        (check-equal? (adapter-supports? adapter 'agent-sandbox) #t)))
    (poo-flow-test-case "exposes request field accessors"
      (let ((task (make-agent-sandbox-task
                   'cube-agent
                   'cube
                   'template-python
                   "python"
                   '("-c" "print('ok')")
                   '((PYTHONUNBUFFERED . "1"))
                   "/workspace"
                   '(((path . "/workspace") (mode . read-write)))
                   '((mode . allow-all))
                   '((network . egress-filtered))
                   '((snapshot . forkable))
                   'artifact
                   '((backend . cube))
                   'unit
                   'artifact)))
        (check-equal? (task-agent-sandbox-backend-kind task) 'cube)
        (check-equal? (task-agent-sandbox-schema task)
                      +agent-sandbox-request-schema+)
        (check-equal? (task-agent-sandbox-backend-ref task) 'template-python)
        (check-equal? (task-agent-sandbox-command task) "python")
        (check-equal? (task-agent-sandbox-args task) '("-c" "print('ok')"))
        (check-equal? (task-agent-sandbox-env task) '((PYTHONUNBUFFERED . "1")))
        (check-equal? (task-agent-sandbox-workdir task) "/workspace")
        (check-equal? (task-agent-sandbox-mounts task)
                      '(((path . "/workspace") (mode . read-write))))
        (check-equal? (task-agent-sandbox-network-policy task)
                      '((mode . allow-all)))
        (check-equal? (task-agent-sandbox-capabilities task)
                      '((network . egress-filtered)))
        (check-equal? (task-agent-sandbox-resource-policy task)
                      '((snapshot . forkable)))
        (check-equal? (task-agent-sandbox-output-policy task) 'artifact)
        (check-equal? (task-agent-sandbox-metadata task) '((backend . cube))))))
  )
