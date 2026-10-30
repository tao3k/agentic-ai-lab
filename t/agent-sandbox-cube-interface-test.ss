;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Cube interface tests cover Marlin-facing lifecycle manifests.
;;; Invariant: tests do not call Cube APIs or create remote sandboxes.

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
        :agentic-ai-lab/modules/agent-sandbox/api
        :agentic-ai-lab/modules/agent-sandbox/cube
        :agentic-ai-lab/modules/agent-sandbox/nono)

(export agent-sandbox-cube-interface-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; This suite keeps Cube backend projection checks isolated from generic
;;; agent-sandbox descriptor coverage.
;; : TestSuite
(def agent-sandbox-cube-interface-test
  (test-suite "CubeSandbox interface contract"
    (yuanxu-test-case "declares POO descriptor for Marlin Cube API handoff"
      (let* ((descriptor (make-cube-interface-descriptor))
             (contract (cube-interface-descriptor->contract descriptor))
             (override (make-cube-interface-descriptor
                        (list (cons 'api-compatibility 'cube-native)))))
        (check-equal? (cube-interface-descriptor? descriptor) #t)
        (check-equal? (test-ref contract 'schema)
                      +cube-interface-schema+)
        (check-equal? (test-ref contract 'backend-kind) 'cube)
        (check-equal? (test-ref contract 'api-compatibility)
                      'e2b-compatible)
        (check-equal? (test-ref contract 'runtime-owner) 'marlin)
        (check-equal? (test-ref contract 'network-modes)
                      '(egress-filtered blocked allow-all proxy-only))
        (check-equal? (cube-interface-descriptor-api-compatibility override)
                      'cube-native)
        (check-equal? (test-ref (car (test-ref contract
                                               'lifecycle-operations))
                                'stage)
                      'resolve-template)))
    (yuanxu-test-case "projects Cube runtime manifests into lifecycle plans"
      (let* ((profile (make-cube-agent-sandbox-profile 'python-template))
             (request (agent-sandbox-request
                       profile
                       (command "python")
                       (args '("-c" "print('cube')"))
                       (env '((PYTHONUNBUFFERED . "1")))
                       (workdir "/workspace")
                       (mounts '(((path . "/workspace")
                                  (mode . read-write))))
                       (network-policy '((mode . egress-filtered)))
                       (resource-policy '((snapshot . clone)
                                          (resume . supported)
                                          (timeout-ms . 60000)))
                       (output-policy 'artifact)
                       (metadata '((purpose . cube-interface-test)))))
             (manifest (agent-sandbox-request->cube-interface-manifest
                        request))
             (interface (test-ref manifest 'interface))
             (backend (test-ref manifest 'backend))
             (template (test-ref manifest 'template))
             (process (test-ref manifest 'process))
             (snapshot-policy (test-ref manifest 'snapshot-policy))
             (lifecycle (test-ref manifest 'lifecycle-plan))
             (resolve-template (car lifecycle))
             (exec-process (list-ref lifecycle 4))
             (snapshot (list-ref lifecycle 6))
             (resume (list-ref lifecycle 7)))
        (check-equal? (test-ref manifest 'schema)
                      +cube-interface-schema+)
        (check-equal? (test-ref interface 'api-compatibility)
                      'e2b-compatible)
        (check-equal? (test-ref backend 'kind) 'cube)
        (check-equal? (test-ref template 'ref) 'python-template)
        (check-equal? (test-ref process 'argv)
                      '("python" "-c" "print('cube')"))
        (check-equal? (test-ref snapshot-policy 'snapshot) 'clone)
        (check-equal? (test-ref snapshot-policy 'resume) 'supported)
        (check-equal? (test-ref resolve-template 'operation)
                      'cube.template.resolve)
        (check-equal? (test-ref (test-ref resolve-template 'template)
                                'ref)
                      'python-template)
        (check-equal? (test-ref exec-process 'operation)
                      'cube.process.exec)
        (check-equal? (test-ref (test-ref exec-process 'process) 'command)
                      "python")
        (check-equal? (test-ref snapshot 'policy) 'clone)
        (check-equal? (test-ref resume 'policy) 'supported)))
    (yuanxu-test-case "rejects non-Cube and unsupported Cube interface policy"
      (let* ((nono-request
              (agent-sandbox-request
               (make-nono-agent-sandbox-profile 'always-further/opencode)
               (command "opencode")
               (mounts '(((path . "/workspace") (mode . read))))))
             (cube-request
              (agent-sandbox-request
               (make-cube-agent-sandbox-profile 'python-template)
               (command "python")
               (mounts '(((path . "/workspace") (mode . execute))))))
             (nono-failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (agent-sandbox-request->cube-interface-manifest
                             nono-request))))
             (mode-failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (agent-sandbox-request->cube-interface-manifest
                             cube-request)))))
        (check-equal? (execution-failure? nono-failure) #t)
        (check-equal? (execution-failure-code nono-failure)
                      'invalid-cube-interface-manifest)
        (check-equal? (execution-failure? mode-failure) #t)
        (check-equal? (execution-failure-code mode-failure)
                      'invalid-cube-interface-manifest)))))
