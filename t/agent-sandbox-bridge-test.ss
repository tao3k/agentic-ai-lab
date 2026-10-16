;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bridge tests cover request envelopes and runtime command handoff.
;;; Invariant: profile descriptor defaults are tested in the profile owner.

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
        :poo-flow/modules/agent-sandbox/api)

(export agent-sandbox-bridge-test)

;; : (-> Value Alist AdapterResult)
(def (bridge-runtime-result value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id '(runtime agent-sandbox-bridge-test))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((runtime . agent-sandbox-bridge-test)))))

;; : (-> ExecutionRequest Alist)
(def (bridge-request-config request)
  (cadr (execution-request-request request)))

;;; This suite locks bridge envelope behavior as executable policy evidence for
;;; agent-sandbox runtime handoff changes.
;; : TestSuite
(def agent-sandbox-bridge-test
  (test-suite "agent sandbox bridge request"
    (poo-flow-test-case "treats non-alist optional metadata as absent"
      (check-equal? (agent-sandbox-alist-ref 'profile-default 'timeout-ms 30000)
                    30000)
      (check-equal? (agent-sandbox-alist-ref '((timeout-ms . 10000))
                                             'timeout-ms
                                             30000)
                    10000)
      (check-equal? (agent-sandbox-merge-alists 'task-local
                                                '((timeout-ms . 30000)))
                    '((timeout-ms . 30000))))
    (poo-flow-test-case "captures backend-neutral request contract"
      (let (seen-request #f)
        (let* ((command (lambda (envelope)
                          (set! seen-request (cdr (assoc 'request envelope)))
                          (bridge-runtime-result 'ok '(artifact agent-output))))
               (config (make-agent-sandbox-run-config
                        (list (cons 'runtime-command command))))
               (flow (agent-sandbox-flow
                      'agent-run
                      'nono
                      'always-further/opencode
                      "opencode"
                      '("--print" "hello")
                      '((OPENAI_API_KEY . redacted))
                      "/workspace"
                      '(((path . ".") (mode . read-write)))
                      '((mode . proxy-only)
                        (allow-hosts . ("api.openai.com")))
                      '((filesystem . scoped)
                        (credentials . injected))
                      '((timeout-ms . 30000)
                        (memory-mb . 512))
                      'artifact
                      '((agent . opencode)
                        (backend . nono))
                      'unit
                      'artifact))
               (result (run-result-value
                        (run-flow-with-config config flow #!void)))
               (sandbox (bridge-request-config seen-request)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-value result) 'ok)
          (check-equal? (execution-request-kind seen-request) 'agent-sandbox)
          (check-equal? (cdr (assoc 'schema sandbox))
                        +agent-sandbox-request-schema+)
          (check-equal? (cdr (assoc 'backend-kind sandbox)) 'nono)
          (check-equal? (cdr (assoc 'backend-ref sandbox))
                        'always-further/opencode)
          (check-equal? (cdr (assoc 'command sandbox)) "opencode")
          (check-equal? (cdr (assoc 'args sandbox))
                        '("--print" "hello"))
          (check-equal? (cdr (assoc 'network-policy sandbox))
                        '((mode . proxy-only)
                          (allow-hosts . ("api.openai.com"))))
          (check-equal? (cdr (assoc 'resource-policy sandbox))
                        '((timeout-ms . 30000)
                          (memory-mb . 512))))))
    (poo-flow-test-case "projects execution requests into bridge envelopes"
      (let ((seen-request #f)
            (seen-envelope #f))
        (let* ((command (lambda (envelope)
                          (set! seen-envelope envelope)
                          (set! seen-request (cdr (assoc 'request envelope)))
                          (bridge-runtime-result 'bridged '(artifact bridge-output))))
               (config (make-agent-sandbox-run-config
                        (list (cons 'runtime-command command))))
               (flow (agent-sandbox-flow
                      'agent-bridge
                      'cube
                      'python-template
                      "python"
                      '("-c" "print('bridge')")
                      '((PYTHONUNBUFFERED . "1"))
                      "/workspace"
                      '(((path . "/workspace") (mode . read-write)))
                      '((mode . egress-filtered))
                      '((isolation . kvm))
                      '((snapshot . clone))
                      'artifact
                      '((backend . cube)
                        (purpose . bridge-test))
                      'unit
                      'artifact))
               (_result (run-result-value
                         (run-flow-with-config config flow #!void)))
               (sandbox (bridge-request-config seen-request))
               (envelope (make-agent-sandbox-bridge-envelope seen-request))
               (manifest (cdr (assoc 'runtime-manifest envelope)))
               (backend (cdr (assoc 'backend manifest)))
               (process (cdr (assoc 'process manifest)))
               (filesystem (cdr (assoc 'filesystem manifest))))
          (check-equal? (agent-sandbox-request? sandbox) #t)
          (check-equal? (agent-sandbox-execution-request? seen-request) #t)
          (check-equal? (agent-sandbox-execution-request-config seen-request)
                        sandbox)
          (check-equal? (cdr (assoc 'schema envelope))
                        +runtime-request-schema+)
          (check-equal? (cdr (assoc 'extension-schema seen-envelope))
                        +agent-sandbox-bridge-schema+)
          (check-equal? (cdr (assoc 'sandbox seen-envelope)) sandbox)
          (check-equal? (cdr (assoc 'extension-schema envelope))
                        +agent-sandbox-bridge-schema+)
          (check-equal? (cdr (assoc 'extension envelope)) 'agent-sandbox)
          (check-equal? (cdr (assoc 'request-schema envelope))
                        +agent-sandbox-request-schema+)
          (check-equal? (cdr (assoc 'backend-kind envelope)) 'cube)
          (check-equal? (cdr (assoc 'backend-ref envelope)) 'python-template)
          (check-equal? (cdr (assoc 'command envelope)) "python")
          (check-equal? (cdr (assoc 'sandbox envelope)) sandbox)
          (check-equal? (cdr (assoc 'schema manifest))
                        +agent-sandbox-runtime-manifest-schema+)
          (check-equal? (cdr (assoc 'kind backend)) 'cube)
          (check-equal? (cdr (assoc 'ref backend)) 'python-template)
          (check-equal? (cdr (assoc 'argv process))
                        '("python" "-c" "print('bridge')"))
          (check-equal? (cdr (assoc 'mounts filesystem))
                        '(((path . "/workspace") (mode . read-write))))
          (check-equal? (cdr (assoc 'network-policy manifest))
                        '((mode . egress-filtered)))
          (check-equal? (cdr (assoc 'resource-policy manifest))
                        '((snapshot . clone)))
          (check-equal? (agent-sandbox-request? '()) #f)
          (check-equal? (agent-sandbox-execution-request? #f) #f))))
    (poo-flow-test-case "rejects non sandbox execution requests before bridge projection"
      (let* ((request
              (make-execution-request
               'compile
               'external
               '(external rust-build ((crate . "poo-flow")))
               'input-artifact
               'artifact
               'artifact
               'plan
               'node
               '()
               #f
               #f))
             (failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (make-agent-sandbox-bridge-envelope request)))))
        (check-equal? (agent-sandbox-execution-request? request) #f)
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-code failure)
                      'invalid-agent-sandbox-execution-request))))
  )
