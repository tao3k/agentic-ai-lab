;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: agent-sandbox profile tests cover profile descriptors and defaults.
;;; Invariant: backend execution stays outside Scheme tests.

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
        :poo-flow/modules/agent-sandbox/nono
        :poo-flow/modules/agent-sandbox/cube)

;;; Fixture result mirrors runtime bridge receipts while keeping the profile
;;; tests independent of an actual sandbox backend.
;; : (-> Value Alist AdapterResult)
(def (runtime-result value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id '(runtime agent-sandbox-profile-test))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((runtime . agent-sandbox-profile-test)))))

;;; Request extraction stays local so assertions track the generated profile
;;; config exactly as the adapter would receive it.
;; : (-> ExecutionRequest Alist)
(def (request-config request)
  (cadr (execution-request-request request)))

;;; Failure code projection keeps validation tests focused on structured error
;;; contracts instead of full diagnostic payload ordering.
;; : (-> ExecutionFailure [Symbol])
(def (failure-error-codes failure)
  (let (entry (assoc 'errors (execution-failure-detail failure)))
    (if entry
      (map (lambda (error)
             (cdr (assoc 'code error)))
           (cdr entry))
      '())))

;;; Local alist lookup keeps summary assertions focused on field contracts.
;; : (-> Symbol Alist MaybeValue)
(def (alist-value key entries)
  (let (entry (and (list? entries) (assoc key entries)))
    (if entry (cdr entry) #f)))

(export agent-sandbox-profile-test)

(def agent-sandbox-profile-test
 (test-suite "agent sandbox profile descriptors"
   (poo-flow-test-case "builds backend profiles for nono and CubeSandbox"
     (let ((nono (make-nono-agent-sandbox-profile 'always-further/opencode))
           (cube (make-cube-agent-sandbox-profile 'python-template)))
       (check-equal? (agent-sandbox-profile-ref nono 'schema #f)
                     +agent-sandbox-profile-schema+)
       (check-equal? (agent-sandbox-profile-backend-kind nono) 'nono)
       (check-equal? (agent-sandbox-profile-backend-ref nono)
                     'always-further/opencode)
       (check-equal? (agent-sandbox-profile-network-policy nono)
                     '((mode . proxy-only)))
       (check-equal? (agent-sandbox-profile-capabilities nono)
                     '((filesystem . scoped)
                       (credentials . injected)))
       (check-equal? (agent-sandbox-profile-resource-policy nono)
                     '((filesystem
                        (scope . runtime)
                        (materialized-by . runtime)
                        (mounts . runtime))
                       (startup . zero-latency)))
       (check-equal? (agent-sandbox-profile-backend-kind cube) 'cube)
       (check-equal? (agent-sandbox-profile-network-policy cube)
                     '((mode . egress-filtered)))
       (check-equal? (agent-sandbox-profile-capabilities cube)
                     '((filesystem . snapshot)
                       (isolation . kvm)
                       (api . e2b-compatible)))
       (check-equal? (agent-sandbox-profile-resource-policy cube)
                     '((filesystem
                        (scope . snapshot)
                        (snapshot . clone))
                       (snapshot . clone)
                       (resume . supported)))))
   (poo-flow-test-case "summarizes structured profiles for runtime handoff"
     (let* ((profile
             (make-agent-sandbox-backend-profile
              'nono
              'local-profile
              '((mode . proxy-only))
              '(process-run filesystem-read filesystem-write tmpdir)
              '((filesystem
                 (scope . project-workspace)
                 (paths
                  ((role . project-workspace)
                   (source . ".")
                   (project-marker . "gerbil.pkg")
                   (target . "/workspace/project")
                   (mode . read-write)))
                 (access . read-write))
                (cpu . 2)
                (memory . "4Gi")
                (timeout-ms . 300000))
              '((intent . coding-agent))))
            (summary (agent-sandbox-profile-runtime-summary profile))
            (filesystem (alist-value 'filesystem summary))
            (handoff (agent-sandbox-profile-handoff-summary profile))
            (handoff-summary (alist-value 'runtime-summary handoff)))
       (check-equal? (alist-value 'schema summary)
                     +agent-sandbox-profile-runtime-summary-schema+)
       (check-equal? (alist-value 'kind summary)
                     'agent-sandbox-profile-runtime-summary)
       (check-equal? (alist-value 'profile-ref summary)
                     'local-profile)
       (check-equal? (alist-value 'backend-kind summary) 'nono)
       (check-equal? (alist-value 'capability-count summary) 4)
       (check-equal? (alist-value 'resource-policy-count summary) 4)
       (check-equal? (alist-value 'valid? summary) #t)
       (check-equal? (alist-value 'validation-errors summary) '())
       (check-equal? (alist-value 'declared? filesystem) #t)
       (check-equal? (alist-value 'structured? filesystem) #t)
       (check-equal? (alist-value 'scope filesystem) 'project-workspace)
       (check-equal? (alist-value 'access filesystem) 'read-write)
       (check-equal? (alist-value 'path-count filesystem) 1)
       (check-equal? (alist-value 'diagnostics filesystem) '())
       (check-equal? (alist-value 'schema handoff)
                     +agent-sandbox-profile-handoff-summary-schema+)
       (check-equal? (alist-value 'handoff-target handoff)
                     "marlin-agent-core")
       (check-equal? (alist-value 'handoff-contract handoff)
                     'poo-flow.agent-sandbox-profile.runtime-handoff.v1)
       (check-equal? (alist-value 'profile handoff) profile)
       (check-equal? (alist-value 'schema handoff-summary)
                     +agent-sandbox-profile-runtime-summary-schema+)
       (check-equal? (alist-value 'runtime-executed handoff) #f)))
   (poo-flow-test-case "uses POO profile descriptors for backend overrides"
     (let* ((cube-descriptor
             (make-cube-agent-sandbox-profile-descriptor 'python-template))
            (override-descriptor
             (make-agent-sandbox-profile-descriptor
              'custom-profile
              'nono
              'base-profile
              '((mode . proxy-only))
              '((filesystem . scoped))
              '((filesystem
                 (scope . project-workspace)
                 (paths
                  ((role . project-workspace)
                   (source . ".")
                   (project-marker . "gerbil.pkg")
                   (target . "/workspace/project")
                   (mode . read-write))))
                (startup . zero-latency))
              '((backend . custom))
              (list (cons 'backend-ref 'override-profile)
                    (cons 'metadata '((backend . override)
                                      (reason . test))))))
            (override-profile
             (agent-sandbox-profile-descriptor->profile override-descriptor)))
       (check-equal? (agent-sandbox-profile-descriptor? cube-descriptor) #t)
       (check-equal? (agent-sandbox-profile-descriptor-name cube-descriptor)
                     'cube-profile)
       (check-equal? (agent-sandbox-profile-descriptor-backend-kind
                      cube-descriptor)
                     'cube)
       (check-equal? (agent-sandbox-profile-backend-ref override-profile)
                     'override-profile)
       (check-equal? (agent-sandbox-profile-metadata override-profile)
                     '((backend . override)
                       (reason . test)))))
   (poo-flow-test-case "validates profile and request contracts before runtime"
     (let* ((invalid-profile
             (make-agent-sandbox-backend-profile 'nono #f '() '() '() '()))
            (profile-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-validate-profile invalid-profile))))
            (valid-profile
             (make-agent-sandbox-backend-profile
              'nono
              'local-profile
              '()
              '()
              '()
              '()))
            (resource-only-profile
             (make-agent-sandbox-backend-profile
              'nono
              'resource-only
              '()
              '(process-run tmpdir)
              '((cpu . 1))
              '()))
            (resource-only-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-validate-profile
                            resource-only-profile))))
            (missing-filesystem-resource-profile
             (make-agent-sandbox-backend-profile
              'nono
              'missing-filesystem-resource
              '()
              '(process-run filesystem-read tmpdir)
              '((cpu . 1))
              '()))
            (missing-filesystem-resource-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-validate-profile
                            missing-filesystem-resource-profile))))
            (unsafe-filesystem-marker-profile
             (make-agent-sandbox-backend-profile
              'nono
              'unsafe-filesystem-marker
              '()
              '(process-run filesystem-read tmpdir)
              '((filesystem . scoped)
                (cpu . 1))
              '()))
            (unsafe-filesystem-marker-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-validate-profile
                            unsafe-filesystem-marker-profile))))
            (filesystem-profile
             (make-agent-sandbox-backend-profile
              'nono
              'filesystem-profile
              '()
              '(process-run filesystem-read tmpdir)
              '((filesystem
                 (scope . project-workspace)
                 (paths
                  ((role . project-workspace)
                   (source . ".")
                   (project-marker . "gerbil.pkg")
                   (target . "/workspace/project")
                   (mode . read-only))))
                (cpu . 1))
              '()))
            (missing-static-source-profile
             (make-agent-sandbox-backend-profile
              'nono
              'missing-static-source
              '()
              '(process-run filesystem-read tmpdir)
              '((filesystem
                 (scope . project-workspace)
                 (paths
                  ((role . project-workspace)
                   (source . ".data/poo-flow-missing-source")
                   (project-marker . "gerbil.pkg")
                   (target . "/workspace/project")
                   (mode . read-only))))
                (cpu . 1))
              '()))
            (missing-static-source-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-validate-profile
                            missing-static-source-profile))))
            (request-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-request
                            valid-profile
                            (command #f)
                            (output-policy 'artifact))))))
       (check-equal? (execution-failure? profile-failure) #t)
       (check-equal? (execution-failure-code profile-failure)
                     'invalid-agent-sandbox-profile)
       (check-equal? (execution-failure? resource-only-failure) #t)
       (check-equal? (execution-failure-code resource-only-failure)
                     'invalid-agent-sandbox-profile)
       (check-equal? (execution-failure? missing-filesystem-resource-failure)
                     #t)
       (check-equal? (execution-failure-code
                      missing-filesystem-resource-failure)
                     'invalid-agent-sandbox-profile)
       (check-equal? (execution-failure? unsafe-filesystem-marker-failure)
                     #t)
       (check-equal? (execution-failure-code
                      unsafe-filesystem-marker-failure)
                     'invalid-agent-sandbox-profile)
       (check-equal? (agent-sandbox-validate-profile filesystem-profile)
                     filesystem-profile)
       (check-equal? (execution-failure? missing-static-source-failure)
                     #t)
       (check-equal? (not (not (memq 'invalid-static-source-path
                                      (failure-error-codes
                                       missing-static-source-failure))))
                     #t)
       (check-equal? (execution-failure? request-failure) #t)
       (check-equal? (execution-failure-code request-failure)
                     'invalid-agent-sandbox-request)))
   (poo-flow-test-case "builds requests with named-field macro contracts"
     (let* ((profile (make-nono-agent-sandbox-profile
                      'always-further/opencode))
            (request (agent-sandbox-request
                      profile
                      (command "opencode")
                      (args '("--print" "typed"))
                      (env '((OPENAI_API_KEY . redacted)))
                      (workdir "/workspace")
                      (mounts '(((path . ".") (mode . read-write))))
                      (network-policy '((mode . blocked)))
                      (output-policy 'artifact)
                      (metadata '((interface . named-fields)))))
            (field-failure
             (with-catch (lambda (failure) failure)
                         (lambda ()
                           (agent-sandbox-request
                            profile
                            (command "opencode")
                            (typo-field #t))))))
       (check-equal? (agent-sandbox-request? request) #t)
       (check-equal? (agent-sandbox-request-ref request 'command #f)
                     "opencode")
       (check-equal? (agent-sandbox-request-ref request 'args '())
                     '("--print" "typed"))
       (check-equal? (agent-sandbox-request-ref request 'network-policy '())
                     '((mode . blocked)))
       (check-equal? (agent-sandbox-request-ref request 'capabilities '())
                     '((filesystem . scoped)
                       (credentials . injected)))
       (check-equal? (execution-failure? field-failure) #t)
       (check-equal? (execution-failure-code field-failure)
                     'invalid-agent-sandbox-request-fields)))
   (poo-flow-test-case "profiled flow normalizes defaults and task overrides"
     (let (seen-request #f)
       (let* ((profile (make-nono-agent-sandbox-profile
                        'always-further/opencode
                        (list (cons 'resource-policy
                                    '((filesystem
                                       (scope . project-workspace)
                                       (paths
                                        ((role . project-workspace)
                                         (source . ".")
                                         (project-marker . "gerbil.pkg")
                                         (target . "/workspace/project")
                                         (mode . read-write))))
                                      (startup . zero-latency)
                                      (profile-timeout-ms . 120000))))))
              (command (lambda (envelope)
                         (set! seen-request (cdr (assoc 'request envelope)))
                         (runtime-result 'profiled '(artifact profiled-output))))
              (config (make-agent-sandbox-run-config
                       (list (cons 'runtime-command command))))
              (flow (profiled-agent-sandbox-flow
                     'profiled-agent
                     profile
                     "opencode"
                     '("--print" "hello")
                     '()
                     "/workspace"
                     '(((path . ".") (mode . read-write)))
                     'artifact
                     'unit
                     'artifact
                     (list (cons 'network-policy '((mode . blocked)))
                           (cons 'resource-policy '((task-timeout-ms . 30000)))
                           (cons 'metadata '((task . profiled-agent))))))
              (result (run-result-value
                       (run-flow-with-config config flow #!void)))
              (sandbox (request-config seen-request)))
         (check-equal? (adapter-result-status result) 'completed)
         (check-equal? (cdr (assoc 'schema sandbox))
                       +agent-sandbox-request-schema+)
         (check-equal? (cdr (assoc 'backend-kind sandbox)) 'nono)
         (check-equal? (cdr (assoc 'backend-ref sandbox))
                       'always-further/opencode)
         (check-equal? (cdr (assoc 'network-policy sandbox))
                       '((mode . blocked)))
         (check-equal? (cdr (assoc 'capabilities sandbox))
                       '((filesystem . scoped)
                         (credentials . injected)))
         (check-equal? (cdr (assoc 'resource-policy sandbox))
                       '((task-timeout-ms . 30000)
                         (filesystem
                          (scope . project-workspace)
                          (paths
                           ((role . project-workspace)
                            (source . ".")
                            (project-marker . "gerbil.pkg")
                            (target . "/workspace/project")
                            (mode . read-write))))
                         (startup . zero-latency)
                         (profile-timeout-ms . 120000)))
         (check-equal? (cdr (assoc 'metadata sandbox))
                       '((task . profiled-agent)
                         (backend . nono)
                         (profile . always-further/opencode))))))))
