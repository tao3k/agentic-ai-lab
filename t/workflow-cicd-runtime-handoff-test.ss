;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD runtime handoff stays inert Scheme control-plane data.
;;; Invariant: manifest and ABI projections never execute sandbox work.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?
                 )
        (only-in :poo-flow/modules/workflow/control-plane/runtime-protocol
                 +runtime-command-descriptor-schema+
                 +runtime-request-schema+)
        :poo-flow/modules/agent-sandbox/config
        :poo-flow/modules/workflow/interface)

(export workflow-cicd-runtime-handoff-test)

;;; Tests inspect projected alists directly; this keeps assertions independent
;;; from the internal POO slot names used to avoid Gerbil object collisions.
;; : (-> Alist Symbol Value)
(def (cicd-runtime-test-alist-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Negative cases should prove validation without leaking exception details
;;; into the public contract.
;; : (-> (-> Value) Boolean)
(def (cicd-runtime-test-error? thunk)
  (let (failure (with-catch (lambda (failure) failure) thunk))
    (error-object? failure)))

;;; The fixture mirrors user-interface CI/CD profile names but remains inert:
;;; no sandbox backend is resolved and no command is executed.
;; : (-> Unit PooFlowCicdCheckMap)
(def (cicd-runtime-test-check-map)
  (poo-flow-cicd-check-map
   'default
   (list
    (poo-flow-cicd-check
     'build
     'ci/build
     '("gerbil" "build")
     '()
     '()
     '(build-log)
     '(gerbil-build-cache)
     '()
     '(read :lines)
     'manifest-handoff
     '((stage . build)))
    (poo-flow-cicd-check
     'test
     'ci/check
     '("gerbil" "env" "./unit-tests.ss")
     '()
     '()
     '(test-receipt)
     '()
     '()
     '(read :lines)
     'manifest-handoff
     '((stage . test)
       (dependency-refs . (build)))))))

;;; Runtime handoff tests pass sandbox profiles explicitly so workflow code
;;; proves only cross-module projection, not backend resource parsing.
;; : [PooSandboxProfile]
(def cicd-runtime-test-sandbox-profiles
  (poo-flow-sandbox-profiles
   (ci/build
    (backend nono)
    (network allowlisted "github.com" "crates.io")
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-write)))
                (access . read-write))
               (cpu . 4)
               (memory . "8Gi")
               (timeout-ms . 600000))
    (metadata (intent . ci-build)
              (scope . cicd)))
   (ci/check
    (backend nono)
    (network deny-by-default)
    (capabilities process-run filesystem-read tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-only)))
                (access . read-only))
               (cpu . 1)
               (memory . "1Gi")
               (timeout-ms . 90000))
    (metadata (intent . ci-check)
              (scope . cicd)))))

;;; Runtime projection is split from receipt construction so the test owner
;;; matches the Marlin handoff boundary and stays below policy complexity caps.
;; : TestSuite
(def workflow-cicd-runtime-handoff-test
  (test-suite "workflow cicd runtime handoff"
    (poo-flow-test-case "projects check-map runtime manifest readiness"
      (let* ((check-map (cicd-runtime-test-check-map))
             (readiness
              (poo-flow-cicd-check-map->runtime-manifest-readiness check-map))
             (dependency-graph
              (cicd-runtime-test-alist-ref readiness 'dependency-graph))
             (dependency-edge
              (car (cicd-runtime-test-alist-ref dependency-graph 'edges)))
             (entries (cicd-runtime-test-alist-ref readiness 'checks))
             (test-entry (cadr entries)))
        (check-equal? (cicd-runtime-test-alist-ref readiness 'schema)
                      +poo-flow-cicd-runtime-manifest-readiness-schema+)
        (check-equal? (cicd-runtime-test-alist-ref readiness 'check-map)
                      'default)
        (check-equal? (cicd-runtime-test-alist-ref readiness
                                                  'runtime-executed)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph 'nodes)
                      '(build test))
        (check-equal? (cicd-runtime-test-alist-ref dependency-edge 'from)
                      'build)
        (check-equal? (cicd-runtime-test-alist-ref dependency-edge 'to)
                      'test)
        (check-equal? (cicd-runtime-test-alist-ref
                       dependency-graph
                       'unresolved-dependency-refs)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph
                                                  'duplicate-nodes)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph
                                                  'cycle-nodes)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph
                                                  'diagnostics)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph 'valid?)
                      #t)
        (check-equal? (length entries) 2)
        (check-equal? (cicd-runtime-test-alist-ref test-entry 'check)
                      'test)
        (check-equal? (cicd-runtime-test-alist-ref test-entry 'profile)
                      'ci/check)
        (check-equal? (cicd-runtime-test-alist-ref test-entry
                                                  'dependency-refs)
                      '(build))
        (check-equal? (cicd-runtime-test-alist-ref
                       test-entry
                       'sandbox-unresolved-profile-refs)
                      '(ci/check))
        (check-equal? (cicd-runtime-test-alist-ref test-entry 'result)
                      '(read :lines))))
    (poo-flow-test-case "projects runtime command manifests from readiness"
      (let* ((check-map (cicd-runtime-test-check-map))
             (manifest-map
              (poo-flow-cicd-check-map->runtime-command-manifests
               check-map
               cicd-runtime-test-sandbox-profiles))
             (manifests (cicd-runtime-test-alist-ref manifest-map
                                                     'manifests))
             (build-manifest (car manifests))
             (test-manifest (cadr manifests))
             (dependency-graph
              (cicd-runtime-test-alist-ref manifest-map 'dependency-graph))
             (dependency-edge
              (car (cicd-runtime-test-alist-ref dependency-graph 'edges)))
             (build-request
              (cicd-runtime-test-alist-ref build-manifest 'request))
             (test-request
              (cicd-runtime-test-alist-ref test-manifest 'request))
             (build-metadata
              (cicd-runtime-test-alist-ref build-manifest 'metadata))
             (test-metadata
              (cicd-runtime-test-alist-ref test-manifest 'metadata)))
        (check-equal? (cicd-runtime-test-alist-ref manifest-map 'kind)
                      'poo-flow.workflow.cicd.runtime-command-manifest-map)
        (check-equal? (cicd-runtime-test-alist-ref manifest-map
                                                  'runtime-executed)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph 'nodes)
                      '(build test))
        (check-equal? (cicd-runtime-test-alist-ref dependency-edge 'from)
                      'build)
        (check-equal? (cicd-runtime-test-alist-ref dependency-edge 'to)
                      'test)
        (check-equal? (length manifests) 2)
        (check-equal? (cicd-runtime-test-alist-ref build-manifest 'schema)
                      +runtime-command-descriptor-schema+)
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'request-schema)
                      +runtime-request-schema+)
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'operation)
                      'workflow-cicd-check)
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'request-id)
                      '(poo-flow.workflow.cicd build))
        (check-equal? (cicd-runtime-test-alist-ref build-manifest 'name)
                      'build)
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'protocol)
                      '(read :lines))
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'executable)
                      "gerbil")
        (check-equal? (cicd-runtime-test-alist-ref build-manifest
                                                  'arguments)
                      '("build"))
        (check-equal? (cicd-runtime-test-alist-ref build-manifest 'argv)
                      '("gerbil" "build"))
        (check-equal? (cicd-runtime-test-alist-ref build-request 'kind)
                      'poo-flow.workflow.cicd.runtime-manifest-ready)
        (check-equal? (cicd-runtime-test-alist-ref
                       build-request
                       'sandbox-unresolved-profile-refs)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref test-request
                                                  'dependency-refs)
                      '(build))
        (check-equal? (cicd-runtime-test-alist-ref build-metadata 'source)
                      'poo-flow.workflow.cicd.check)
        (check-equal? (cicd-runtime-test-alist-ref build-metadata
                                                  'runtime-executed)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref test-metadata
                                                  'dependency-refs)
                      '(build))
        (check-equal? (cicd-runtime-test-alist-ref test-metadata
                                                  'runtime-executed)
                      #f)))
    (poo-flow-test-case "exports Marlin runtime handoff ABI without execution"
      (let* ((check-map (cicd-runtime-test-check-map))
             (abi (poo-flow-cicd-check-map->marlin-runtime-handoff-abi
                   check-map
                   cicd-runtime-test-sandbox-profiles))
             (dependency-graph
              (cicd-runtime-test-alist-ref abi 'dependency-graph))
             (entries (cicd-runtime-test-alist-ref abi 'entries))
             (build-entry (car entries))
             (test-entry (cadr entries))
             (build-request
              (cicd-runtime-test-alist-ref build-entry 'request))
             (test-policy
              (cicd-runtime-test-alist-ref test-entry 'policy))
             (test-metadata
              (cicd-runtime-test-alist-ref test-entry 'metadata)))
        (check-equal? (cicd-runtime-test-alist-ref abi 'schema)
                      +poo-flow-cicd-marlin-runtime-handoff-abi-schema+)
        (check-equal? (cicd-runtime-test-alist-ref abi 'kind)
                      'poo-flow.workflow.cicd.marlin-runtime-handoff-abi)
        (check-equal? (cicd-runtime-test-alist-ref abi 'check-map)
                      'default)
        (check-equal? (cicd-runtime-test-alist-ref abi 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (cicd-runtime-test-alist-ref abi 'runtime-executed)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref
                       abi
                       'runtime-parses-scheme-source)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref
                       abi
                       'scheme-manufactures-runtime-handlers)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref abi 'manifest-count) 2)
        (check-equal? (cicd-runtime-test-alist-ref abi 'required-fields)
                      '(operation
                        request-id
                        artifact-handle
                        argv
                        request
                        policy
                        plan-id
                        node-id
                        frontier
                        durable-task-id
                        action-class
                        artifact-refs
                        artifact-provenance
                        artifact-retention
                        sandbox-refs
                        checkpoint-ref
                        compensation-refs
                        runtime-owner
                        handoff-required
                        runtime-executed))
        (check-equal? (cicd-runtime-test-alist-ref dependency-graph 'nodes)
                      '(build test))
        (check-equal? (length entries) 2)
        (check-equal? (cicd-runtime-test-alist-ref build-entry 'kind)
                      'poo-flow.workflow.cicd.marlin-runtime-handoff-entry)
        (check-equal? (cicd-runtime-test-alist-ref build-entry 'operation)
                      'workflow-cicd-check)
        (check-equal? (cicd-runtime-test-alist-ref build-entry 'request-id)
                      '(poo-flow.workflow.cicd build))
        (check-equal? (cicd-runtime-test-alist-ref build-entry 'argv)
                      '("gerbil" "build"))
        (check-equal? (cicd-runtime-test-alist-ref
                       build-request
                       'sandbox-unresolved-profile-refs)
                      '())
        (check-equal? (cicd-runtime-test-alist-ref test-policy
                                                  'dependency-refs)
                      '(build))
        (check-equal? (cicd-runtime-test-alist-ref test-metadata
                                                  'dependency-refs)
                      '(build))
        (check-equal? (cicd-runtime-test-alist-ref test-entry
                                                  'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (cicd-runtime-test-alist-ref test-entry
                                                  'handoff-required)
                      #t)
        (check-equal? (cicd-runtime-test-alist-ref test-entry
                                                  'runtime-executed)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref
                       test-entry
                       'runtime-parses-scheme-source)
                      #f)
        (check-equal? (cicd-runtime-test-alist-ref
                       test-entry
                       'scheme-manufactures-runtime-handlers)
                      #f)))
    (poo-flow-test-case "rejects unsafe fake check shapes"
      (check-equal?
       (cicd-runtime-test-error?
        (lambda ()
          (poo-flow-cicd-check
           'bad
           'ci/build
           '()
           '()
           '()
           '()
           '()
           '()
           '(read :lines)
           'manifest-handoff)))
       #t)
      (check-equal?
       (cicd-runtime-test-error?
        (lambda ()
          (poo-flow-cicd-check-map 'bad '(not-a-check))))
       #t))))
