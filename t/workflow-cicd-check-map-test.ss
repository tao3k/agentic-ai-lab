;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD check maps are inert POO control-plane data.
;;; Invariant: tests prove receipts and runtime readiness without execution.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?
                 )
        (only-in :clan/poo/object .ref object?)
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/workflow/interface)

(export workflow-cicd-check-map-test)

;;; Tests inspect projected alists directly; this keeps assertions independent
;;; from the internal POO slot names used to avoid Gerbil object collisions.
;; : (-> Alist Symbol Value)
(def (cicd-test-alist-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; The fixture mirrors user-interface CI/CD profile names but remains inert:
;;; no sandbox backend is resolved and no command is executed.
;; : (-> Unit YuanxuCicdCheckMap)
(def (cicd-test-check-map)
  (yuanxu-cicd-check-map
   'default
   (list
    (yuanxu-cicd-check
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
    (yuanxu-cicd-check
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

;;; The sandbox profile catalog is optional. Tests pass it explicitly to prove
;;; check-map readiness can consume sandbox-owned summaries without owning
;;; filesystem/resource policy parsing.
;; : (-> Unit [PooSandboxProfile])
(def cicd-test-sandbox-profiles
  (agentic-ai-lab-sandbox-profiles
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

;;; This suite is the acceptance gate for the Milestone 3 bridge from Funflow
;;; =+cicd= intent to concrete Scheme receipts and manifest-readiness data.
;; : TestSuite
(def workflow-cicd-check-map-test
  (test-suite "workflow cicd check map"
    (yuanxu-test-case "constructs named POO checks and check maps"
      (let* ((check-map (cicd-test-check-map))
             (checks (yuanxu-cicd-check-map-checks check-map))
             (build-check (car checks))
             (test-check (cadr checks)))
        (check-equal? (object? check-map) #t)
        (check-equal? (yuanxu-cicd-check-map? check-map) #t)
        (check-equal? (.ref check-map 'kind)
                      (yuanxu-cicd-check-map-kind))
        (check-equal? (yuanxu-cicd-check-map-name check-map) 'default)
        (check-equal? (length checks) 2)
        (check-equal? (yuanxu-cicd-check? build-check) #t)
        (check-equal? (yuanxu-cicd-check? test-check) #t)
        (check-equal? (yuanxu-cicd-check-name build-check) 'build)
        (check-equal? (yuanxu-cicd-check-profile build-check) 'ci/build)
        (check-equal? (yuanxu-cicd-check-command test-check)
                      '("gerbil" "env" "./unit-tests.ss"))
        (check-equal? (yuanxu-cicd-check-dependency-refs build-check)
                      '())
        (check-equal? (yuanxu-cicd-check-dependency-refs test-check)
                      '(build))
        (check-equal? (.ref check-map 'runtime-executed) #f)))
    (yuanxu-test-case "projects check receipts without running runtime work"
      (let* ((check-map (cicd-test-check-map))
             (receipts (agentic-ai-lab-cicd-check-map->receipts check-map))
             (build-receipt (car receipts))
             (test-receipt (cadr receipts))
             (runtime-ready
              (cicd-test-alist-ref build-receipt
                                    'runtime-manifest-ready))
             (test-runtime-ready
              (cicd-test-alist-ref test-receipt
                                    'runtime-manifest-ready)))
        (check-equal? (length receipts) 2)
        (check-equal? (cicd-test-alist-ref build-receipt 'schema)
                      +yuanxu-cicd-check-receipt-schema+)
        (check-equal? (cicd-test-alist-ref build-receipt 'check) 'build)
        (check-equal? (cicd-test-alist-ref build-receipt 'profile) 'ci/build)
        (check-equal? (cicd-test-alist-ref build-receipt 'command)
                      '("gerbil" "build"))
        (check-equal? (cicd-test-alist-ref build-receipt 'artifacts)
                      '(build-log))
        (check-equal? (cicd-test-alist-ref build-receipt 'cache)
                      '(gerbil-build-cache))
        (check-equal? (cicd-test-alist-ref build-receipt 'secrets) '())
        (check-equal? (cicd-test-alist-ref build-receipt 'runtime)
                      'manifest-handoff)
        (check-equal? (cicd-test-alist-ref build-receipt
                                           'dependency-refs)
                      '())
        (check-equal? (cicd-test-alist-ref test-receipt
                                           'dependency-refs)
                      '(build))
        (check-equal? (cicd-test-alist-ref build-receipt 'runtime-executed)
                      #f)
        (check-equal? (cicd-test-alist-ref test-runtime-ready
                                           'dependency-refs)
                      '(build))
        (check-equal? (cicd-test-alist-ref runtime-ready 'handoff-required)
                      #t)
        (check-equal? (cicd-test-alist-ref runtime-ready 'runtime-executed)
                      #f)
        (check-equal? (cicd-test-alist-ref runtime-ready
                                           'sandbox-runtime-summaries)
                      '())
        (check-equal? (cicd-test-alist-ref runtime-ready
                                           'sandbox-unresolved-profile-refs)
                      '(ci/build))
        (check-equal? (cicd-test-alist-ref runtime-ready 'argv)
                      '("gerbil" "build"))))
    (yuanxu-test-case "resolves sandbox profile summaries when catalog is provided"
      (let* ((check-map (cicd-test-check-map))
             (receipts
              (agentic-ai-lab-cicd-check-map->receipts
               check-map
               cicd-test-sandbox-profiles))
             (build-receipt (car receipts))
             (runtime-ready
              (cicd-test-alist-ref build-receipt
                                    'runtime-manifest-ready))
             (sandbox-summaries
              (cicd-test-alist-ref runtime-ready
                                    'sandbox-runtime-summaries))
             (build-summary (car sandbox-summaries))
             (build-filesystem
              (cicd-test-alist-ref build-summary 'filesystem))
             (handoff-summaries
              (cicd-test-alist-ref runtime-ready
                                    'sandbox-handoff-summaries))
             (build-handoff (car handoff-summaries)))
        (check-equal? (cicd-test-alist-ref runtime-ready 'profile-refs)
                      '(ci/build))
        (check-equal? (cicd-test-alist-ref runtime-ready
                                           'sandbox-unresolved-profile-refs)
                      '())
        (check-equal? (cicd-test-alist-ref build-summary 'schema)
                      'agentic-ai-lab.agent-sandbox-profile.runtime-summary.v1)
        (check-equal? (cicd-test-alist-ref build-summary 'profile-name)
                      'ci/build)
        (check-equal? (cicd-test-alist-ref build-summary 'valid?) #t)
        (check-equal? (cicd-test-alist-ref build-filesystem 'scope)
                      'project-workspace)
        (check-equal? (cicd-test-alist-ref build-filesystem 'path-count) 1)
        (check-equal? (cicd-test-alist-ref build-handoff 'schema)
                      'agentic-ai-lab.agent-sandbox-profile.handoff-summary.v1)
        (check-equal? (cicd-test-alist-ref build-receipt
                                           'sandbox-runtime-summaries)
                      sandbox-summaries)))))
