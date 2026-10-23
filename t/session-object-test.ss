;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session objects inspired by OpenRath's session-first
;;; model.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-default-sandbox-profiles)
        :poo-flow/modules/session/config)

(export session-object-test)

;;; Resolved placement keeps sandbox profile validation at the sandbox owner
;;; while letting session tests assert report-only catalog linkage.
;; : PooSessionPlacement
(def session-placement
  (poo-flow-session-placement-resolve
   'agent/nono
   poo-flow-default-sandbox-profiles
   '((source . session-object-test))))

;; : PooSessionPlacement
(def session-missing-placement
  (poo-flow-session-placement-resolve
   'agent/missing
   poo-flow-default-sandbox-profiles))

;;; Root and child fixtures model a forkable session tree without invoking a
;;; runtime harness; they are stable inputs for graph and handoff projection.
;; : PooSession
(def session-root
  (poo-flow-session-value
   'root
   (list (poo-flow-session-chunk 'request 'user "Build the project."))
   (poo-flow-session-lineage 'root '() 'root)
   session-placement
   '((intent . package-check))))

;; : PooSession
(def session-child
  (poo-flow-session-value
   'child
   (list (poo-flow-session-chunk 'review 'assistant "Review the build receipt."))
   (poo-flow-session-lineage 'child '(root) 'fork)
   session-placement
   '((intent . build-review))))

;; : PooSession
(def session-macro-root
  (session macro/root
    (chunk request user "Run package checks.")
    (lineage root)
    (placement agent/nono)
    (metadata (intent . tutorial-ladder)
              (source . macro-test))))

;; : PooSession
(def session-macro-child
  (session macro/child
    (chunk review assistant "Review the session receipt.")
    (lineage fork macro/root)
    (placement agent/nono)
    (metadata (intent . tutorial-ladder)
              (source . macro-test)
              (branch . review))))

;;; Cycle fixtures are intentionally invalid graph data. They verify the graph
;;; presenter reports acyclicity instead of throwing during construction.
;; : PooSession
(def session-cycle-root
  (poo-flow-session-value
   'cycle-root
   (list (poo-flow-session-chunk 'cycle 'user "Cycle root."))
   (poo-flow-session-lineage 'cycle-root '(cycle-child) 'fork)
   session-placement))

;; : PooSession
(def session-cycle-child
  (poo-flow-session-value
   'cycle-child
   (list (poo-flow-session-chunk 'cycle-child 'assistant "Cycle child."))
   (poo-flow-session-lineage 'cycle-child '(cycle-root) 'fork)
   session-placement))

;;; The suite keeps constructor, handoff, graph, and cycle checks together so
;;; public session names remain consistent across the facade.
;; : TestSuite
(def session-object-test
  (test-suite "poo-flow report-only session objects"
    (yuanxu-test-case "builds chunks, lineage, placement, and handoff receipts"
      (let* ((handoff (poo-flow-session-handoff session-child))
             (handoff-alist (poo-flow-session-handoff->alist handoff)))
        (check-equal? (poo-flow-session? session-root) #t)
        (check-equal? (poo-flow-session-chunk-role
                       (car (poo-flow-session-chunks session-root)))
                      'user)
        (check-equal? (poo-flow-session-lineage-parent-session-ids
                       (poo-flow-session-value-lineage session-child))
                      '(root))
        (check-equal? (poo-flow-session-placement-profile-ref
                       (poo-flow-session-value-placement session-child))
                      'agent/nono)
        (check-equal? (poo-flow-session-placement-resolved?
                       (poo-flow-session-value-placement session-child))
                      #t)
        (check-equal? (poo-flow-session-alist-ref
                       (poo-flow-session-placement-runtime-summary
                        (poo-flow-session-value-placement session-child))
                       'profile-name
                       #f)
                      'agent/nono)
        (check-equal? (poo-flow-session-alist-ref handoff-alist 'session-id #f) 'child)
        (check-equal? (poo-flow-session-alist-ref handoff-alist 'placement-resolved? #f) #t)
        (check-equal? (poo-flow-session-alist-ref handoff-alist 'runtime-owner #f) "marlin-agent-core")
        (check-equal? (poo-flow-session-alist-ref handoff-alist 'runtime-executed #t) #f)))
    (yuanxu-test-case "presents session graph without runtime execution"
      (let (presentation
            (pooFlowSessionGraphPresentation
             (list session-root session-child)))
        (check-equal? (.ref presentation 'session-count) 2)
        (check-equal? (.ref presentation 'session-ids) '(root child))
        (check-equal? (.ref presentation 'chunk-count) 2)
        (check-equal? (.ref presentation 'lineage-edge-pairs)
                      '((root . child)))
        (check-equal? (.ref presentation 'placement-profile-refs)
                      '(agent/nono agent/nono))
        (check-equal? (.ref presentation 'placement-resolved?)
                      '(#t #t))
        (check-equal? (.ref presentation 'acyclic?) #t)
        (check-equal? (.ref presentation 'runtime-executed) #f)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)))
    (yuanxu-test-case "detects cyclic lineage as structured validation data"
      (let (presentation
            (pooFlowSessionGraphPresentation
             (list session-cycle-root session-cycle-child)))
        (check-equal? (.ref presentation 'acyclic?) #f)
        (check-equal? (.ref presentation 'lineage-edge-pairs)
                      '((cycle-child . cycle-root)
                        (cycle-root . cycle-child)))))
    (yuanxu-test-case "reports missing placement profiles without runtime execution"
      (let (diagnostic
            (car (poo-flow-session-placement-diagnostics
                  session-missing-placement)))
        (check-equal? (poo-flow-session-placement-profile-ref
                       session-missing-placement)
                      'agent/missing)
        (check-equal? (poo-flow-session-placement-resolved?
                       session-missing-placement)
                      #f)
        (check-equal? (poo-flow-session-alist-ref diagnostic 'status #f)
                      'missing-profile)
        (check-equal? (poo-flow-session-placement-runtime-summary
                       session-missing-placement)
                      '())))
    (yuanxu-test-case "declares sessions through compact user syntax"
      (let ((presentation
             (session-graph session-macro-root session-macro-child))
            (child-placement
             (poo-flow-session-value-placement session-macro-child)))
        (check-equal? (poo-flow-session-id session-macro-root)
                      'macro/root)
        (check-equal? (poo-flow-session-lineage-parent-session-ids
                       (poo-flow-session-value-lineage session-macro-child))
                      '(macro/root))
        (check-equal? (poo-flow-session-alist-ref
                       (poo-flow-session-metadata session-macro-child)
                       'branch
                       #f)
                      'review)
        (check-equal? (poo-flow-session-placement-profile-ref child-placement)
                      'agent/nono)
        (check-equal? (poo-flow-session-placement-resolved? child-placement)
                      #t)
        (check-equal? (.ref presentation 'session-ids)
                      '(macro/root macro/child))
        (check-equal? (.ref presentation 'lineage-edge-pairs)
                      '((macro/root . macro/child)))))))
