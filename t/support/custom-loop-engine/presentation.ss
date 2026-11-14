;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Presentation checks for custom loop-engine tests.
;;; Boundary: helpers mirror public doctor slots back to projected intent facts.
;;; Invariant: presentation checks assert report-only rows and never execute loops.

(import (only-in :std/test check-equal?)
        (only-in :clan/poo/object .ref)
        "./fixtures")

(export check-custom-loop-presentation-boundary)

;; : (-> POOObject Alist [Pair] [List])
(def (presentation-intent-slot-expectations presentation intent slot-pairs)
  (map (lambda (entry)
         (list (car (.ref presentation (car entry)))
               (test-ref intent (cdr entry))))
       slot-pairs))

;; : (-> POOObject Alist [Pair] Void)
(def (check-presentation-intent-slots! presentation intent slot-pairs)
  (for-each
   (lambda (expected)
     (check-equal? (car expected) (cadr expected)))
   (presentation-intent-slot-expectations presentation intent slot-pairs)))

;;; Runtime snapshot checks prove the public doctor view stays report-only.
;; : (-> Alist)
(def (check-custom-loop-runtime-snapshot! runtime-snapshot)
  (check-equal? (test-ref runtime-snapshot 'kind) 'runtime-snapshot)
  (check-equal? (test-ref runtime-snapshot 'subject-kind) 'loop-engine)
  (check-equal? (test-ref runtime-snapshot 'subject-id)
                'current-system-build-loop)
  (check-equal? (test-ref runtime-snapshot 'status) 'waiting-human)
  (check-equal? (test-ref (test-ref runtime-snapshot 'metadata)
                          'handoff-ready?)
                #f))

;;; Presentation graph slots must expose the same graph rows used by the handoff.
;; : (-> POOObject Alist)
(def (check-custom-loop-presentation-graph! presentation intent)
  (check-equal? (.ref presentation 'loop-engine-runtime-snapshot-count) 1)
  (check-presentation-intent-slots!
   presentation
   intent
   '((loop-engine-agent-profiles . agent-profiles)
     (loop-engine-result-contracts . result-contract)
     (loop-engine-sandbox-handoff-agreements . sandbox-handoff-agreement)
     (loop-engine-agent-harnesses . agent-harnesses)
     (loop-engine-agent-sessions . agent-sessions)
     (loop-engine-session-agent-graphs . session-agent-graph)
     (loop-engine-session-agent-topology-traces
      . session-agent-topology-trace)))
  (check-equal? (car (.ref presentation 'loop-engine-receipt-contracts))
                expected-loop-engine-receipt-contracts))

;;; Presentation operation and receipt slots mirror selected loop behavior while
;;; keeping runtime execution out of Scheme tests.
;; : (-> POOObject)
(def (check-custom-loop-presentation-runtime-rows! presentation)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-runtime-snapshots))
                          'status)
                'waiting-human)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-agent-operations))
                          'operation-kind)
                'human-audit)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-delegated-operations))
                          'governor-agent)
                'ci-loop-governor)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-delegated-operations))
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-lineage-receipts))
                          'lineage-kind)
                'guarded-handoff)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-selector-receipts))
                          'selected-branch)
                'current-system-build-loop)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-resource-dispatch-receipts))
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-capability-receipts))
                          'backend)
                'nono)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-memory-receipts))
                          'store)
                'project-memory)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-memory-receipts))
                          'selected-use-case)
                'current-system-build-loop)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-compression-receipts))
                          'trigger)
                'after-human-audit))

;;; Presentation manifest slots ensure every generated row remains correlated
;;; with its report-only receipt contract.
;; : (-> POOObject)
(def (check-custom-loop-presentation-manifests! presentation)
  (check-equal? (test-field-values
                 (car (.ref presentation
                             'loop-engine-spec-evolution-human-audit-review-items))
                 'pattern)
                (list expected-loop-engine-spec-evolution-proposal-id))
  (check-equal? (test-field-values
                 (car (.ref presentation
                             'loop-engine-spec-evolution-runtime-manifest-rows))
                 'eligible-for-checked-mutation)
                '(#t))
  (check-equal? (test-field-values
                 (car (.ref presentation
                             'loop-engine-session-selector-receipts))
                 'selector-id)
                '(selector/current-system-loop-router))
  (check-equal? (test-field-values
                 (car (.ref presentation
                             'loop-engine-session-materialization-receipts))
                 'session-ref)
                '(current-system-build-session
                  current-system-recovery-session))
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-runtime-command-manifests))
                          'operation)
                'loop-engine-handoff)
  (check-equal? (test-ref (car (.ref presentation
                                  'loop-engine-runtime-command-manifest-summaries))
                          'contract)
                'agentic-ai-lab.loop-governor.runtime-command-manifest.v1))

;;; Presentation assertions verify the public doctor view exposes the same
;;; object graph rows that the runtime manifest carries.
;; : (-> POOObject Alist Alist)
(def (check-custom-loop-presentation-boundary presentation
                                              intent
                                              runtime-snapshot)
  (check-custom-loop-runtime-snapshot! runtime-snapshot)
  (check-custom-loop-presentation-graph! presentation intent)
  (check-custom-loop-presentation-runtime-rows! presentation)
  (check-custom-loop-presentation-manifests! presentation))
