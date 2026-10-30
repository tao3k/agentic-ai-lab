;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests inspect the user-facing Funflow CI/CD dependency graph.
;;; Invariant: graph projection stays declarative and runtime-free.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :agentic-ai-lab/modules/workflow/cicd-runtime-command-config
                 agentic-ai-lab-user-config-workflow-cicd-runtime-readiness
                 agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
                 agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
                 agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement)
        (only-in :agentic-ai-lab/modules/workflow/funs
                 agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi)
        (only-in "./support/user-interface-cicd-runtime-fixture"
                 user-interface-cicd-runtime-fixture-config))

(export user-interface-cicd-runtime-graph-test)

;; : (-> Alist Symbol Value)
(def (user-interface-cicd-runtime-graph-alist-ref entries key)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

;; : (-> CicdRuntimeGraphContext Symbol Value)
(def (user-interface-cicd-runtime-graph-context-ref context key)
  (user-interface-cicd-runtime-graph-alist-ref context key))

;; : (-> CicdRuntimeGraphContext)
(def (user-interface-cicd-runtime-graph-context)
  (let* ((config (user-interface-cicd-runtime-fixture-config))
         (readiness-rows
          (agentic-ai-lab-user-config-workflow-cicd-runtime-readiness config))
         (readiness
          (car readiness-rows))
         (checks
          (user-interface-cicd-runtime-graph-alist-ref readiness 'checks))
         (manifest-maps
          (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
           config))
         (manifest-map
          (car manifest-maps))
         (dependency-graph
          (user-interface-cicd-runtime-graph-alist-ref
           manifest-map
           'dependency-graph))
         (dependency-edges
          (user-interface-cicd-runtime-graph-alist-ref
           dependency-graph
           'edges))
         (manifests
          (user-interface-cicd-runtime-graph-alist-ref
           manifest-map
           'manifests))
         (build-manifest (car manifests))
         (manifest-summaries
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
           manifest-maps))
         (agreement
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
           manifest-maps
           manifest-summaries))
         (agreement-rows
          (user-interface-cicd-runtime-graph-alist-ref agreement 'rows))
         (handoff-abi
          (agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
           manifest-map))
         (handoff-entries
          (user-interface-cicd-runtime-graph-alist-ref
           handoff-abi
           'entries)))
    (list
     (cons 'manifest-maps manifest-maps)
     (cons 'manifest-summaries manifest-summaries)
     (cons 'readiness readiness)
     (cons 'checks checks)
     (cons 'manifest-map manifest-map)
     (cons 'dependency-graph dependency-graph)
     (cons 'dependency-edges dependency-edges)
     (cons 'build-edge (car dependency-edges))
     (cons 'package-edge (cadr dependency-edges))
     (cons 'manifests manifests)
     (cons 'build-manifest build-manifest)
     (cons 'build-request
           (user-interface-cicd-runtime-graph-alist-ref
            build-manifest
            'request))
     (cons 'build-policy
           (user-interface-cicd-runtime-graph-alist-ref
            build-manifest
            'policy))
     (cons 'build-summary (car manifest-summaries))
     (cons 'test-summary (cadr manifest-summaries))
     (cons 'package-summary (caddr manifest-summaries))
     (cons 'agreement agreement)
     (cons 'build-agreement-row (car agreement-rows))
     (cons 'package-agreement-row (caddr agreement-rows))
     (cons 'build-handoff-entry (car handoff-entries))
     (cons 'runtime-summaries
           (user-interface-cicd-runtime-graph-alist-ref
            (car checks)
            'sandbox-runtime-summaries)))))

;; : (-> CicdRuntimeGraphContext Void)
(def (check-cicd-runtime-readiness! context)
  (let* ((readiness
          (user-interface-cicd-runtime-graph-context-ref context 'readiness))
         (checks
          (user-interface-cicd-runtime-graph-context-ref context 'checks))
         (agreement
          (user-interface-cicd-runtime-graph-context-ref context 'agreement))
         (build-agreement-row
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'build-agreement-row))
         (package-agreement-row
          (user-interface-cicd-runtime-graph-context-ref
           context
           'package-agreement-row))
         (runtime-summaries
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'runtime-summaries))
         (manifest-maps
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'manifest-maps))
         (manifest-summaries
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'manifest-summaries)))
    (check-equal? (length checks) 3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref (car checks) 'check)
     'build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref (cadr checks) 'check)
     'test)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref (caddr checks) 'check)
     'package)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref
      (car runtime-summaries)
      'profile-name)
     'ci/build)
    (check-equal?
     (length manifest-maps)
     1)
    (check-equal?
     (length manifest-summaries)
     3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'valid?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'diagnostics)
     '())
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'manifest-count)
     3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'summary-count)
     3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'agreement-count)
     3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref agreement 'valid?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row 'check)
     'build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row
                                                  'argv-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row
                                                  'runtime-owner-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref
      build-agreement-row
      'unresolved-profile-refs-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row
                                                  'runtime-executed-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row
                                                  'durable-task-id-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row
                                                  'artifact-provenance-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-agreement-row
                                                  'compensation-refs-match?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-agreement-row 'valid?)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref readiness 'runtime-executed)
     #f)))

;; : (-> CicdRuntimeGraphContext Void)
(def (check-cicd-dependency-graph! context)
  (let* ((manifest-map
          (user-interface-cicd-runtime-graph-context-ref context 'manifest-map))
         (dependency-graph
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'dependency-graph))
         (dependency-edges
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'dependency-edges))
         (build-edge
          (user-interface-cicd-runtime-graph-context-ref context 'build-edge))
         (package-edge
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'package-edge)))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref manifest-map 'kind)
     'agentic-ai-lab.workflow.cicd.runtime-command-manifest-map)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph 'nodes)
     '(build test package))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph
                                                  'order-policy)
     'declaration-topological-report)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph
                                                  'ready-order)
     '(build test package))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph
                                                  'unordered-nodes)
     '())
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph
                                                  'blocked-order?)
     #f)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph 'valid?)
     #t)
    (check-equal? (length dependency-edges) 2)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-edge 'from)
     'build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-edge 'to)
     'test)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-edge 'from)
     'test)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-edge 'to)
     'package)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref dependency-graph
                                                  'unresolved-dependency-refs)
     '())))

;; : (-> CicdRuntimeGraphContext Void)
(def (check-cicd-build-manifest! context)
  (let* ((manifests
          (user-interface-cicd-runtime-graph-context-ref context 'manifests))
         (build-manifest
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'build-manifest))
         (build-request
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'build-request))
         (build-policy
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'build-policy)))
    (check-equal? (length manifests) 3)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-manifest 'argv)
     '("gerbil" "build"))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request 'check)
     'build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request
                                                  'durable-task-id)
     'task/build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request 'action-class)
     'idempotent)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request 'artifact-refs)
     '(build-log))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request
                                                  'artifact-retention)
     'project-retained)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request 'sandbox-refs)
     '(ci/build))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request
                                                  'checkpoint-ref)
     '(workflow-cicd-check build))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-request
                                                  'compensation-refs)
     '())
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-policy
                                                  'durable-task-id)
     'task/build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-policy
                                                  'artifact-provenance)
     '(((artifact-ref . build-log)
        (producer-check . build)
        (durable-task-id . task/build)
        (retention . project-retained)
        (runtime-owner . "marlin-agent-core")
        (runtime-executed . #f))))))

;; : (-> CicdRuntimeGraphContext Void)
(def (check-cicd-manifest-summaries! context)
  (let* ((build-summary
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'build-summary))
         (test-summary
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'test-summary))
         (package-summary
          (user-interface-cicd-runtime-graph-context-ref context
                                                         'package-summary)))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary 'kind)
     'workflow-cicd-runtime-command-manifest-summary)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary 'check)
     'build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary 'argv)
     '("gerbil" "build"))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary
                                                  'durable-task-id)
     'task/build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary
                                                  'artifact-provenance)
     '(((artifact-ref . build-log)
        (producer-check . build)
        (durable-task-id . task/build)
        (retention . project-retained)
        (runtime-owner . "marlin-agent-core")
        (runtime-executed . #f))))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary
                                                  'runtime-owner)
     "marlin-agent-core")
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref
      build-summary
      'sandbox-unresolved-profile-refs)
     '())
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary 'status)
     'ready)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-summary 'handoff-ready)
     #t)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref test-summary
                                                  'dependency-refs)
     '(build))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary 'check)
     'package)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary
                                                  'dependency-refs)
     '(test))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary
                                                  'durable-task-id)
     'task/package)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary
                                                  'action-class)
     'compensatable)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary
                                                  'artifact-retention)
     'release-retained)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref package-summary
                                                  'compensation-refs)
     '(cleanup/package-artifacts))))

;; : (-> CicdRuntimeGraphContext Void)
(def (check-cicd-handoff-entry! context)
  (let (build-handoff-entry
        (user-interface-cicd-runtime-graph-context-ref context
                                                       'build-handoff-entry))
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-handoff-entry
                                                  'durable-task-id)
     'task/build)
    (check-equal?
     (user-interface-cicd-runtime-graph-alist-ref build-handoff-entry
                                                  'artifact-refs)
     '(build-log))))

;;; The custom Funflow case is the downstream user contract: the focused
;;; production projection must expose the three-node graph and the same ordered
;;; rows used for runtime manifest handoff, without executing the adapter.
;; : TestSuite
(def user-interface-cicd-runtime-graph-test
  (test-suite "agentic-ai-lab user interface cicd runtime graph"
    (yuanxu-test-case "keeps workflow CI/CD graph projection inspectable"
      (let (context (user-interface-cicd-runtime-graph-context))
        (check-cicd-runtime-readiness! context)
        (check-cicd-dependency-graph! context)
        (check-cicd-build-manifest! context)
        (check-cicd-manifest-summaries! context)
        (check-cicd-handoff-entry! context)))))
