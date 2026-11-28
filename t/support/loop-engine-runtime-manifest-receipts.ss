;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared assertions for loop-engine runtime manifest receipts.
;;; Invariant: helpers inspect inert request rows only; they never construct or
;;; execute runtime manifests.

(import (only-in :std/test check-equal?))

(export check-custom-loop-runtime-manifest-request-receipts)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;; : Symbol
(def expected-loop-engine-spec-evolution-proposal-id
  'sandbox-profile-human-audit-before-ci-change)

;;; Manifest receipt assertions verify policy receipts survive serialization
;;; into the runtime request without becoming runtime actions.
;; : (-> Alist)
(def (check-custom-loop-runtime-manifest-request-receipts
      runtime-manifest-request)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'contract)
                'agentic-ai-lab.loop-engine.lineage-receipt.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'parent-session-refs)
                '(incoming-ci-request-session))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'lineage-kind)
                'guarded-handoff)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'lineage-operator)
                'current-system-build-loop)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'selector-receipt)
                          'contract)
                'agentic-ai-lab.loop-engine.selector-receipt.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'selector-receipt)
                          'candidates)
                '(current-system-build-loop current-system-recovery-loop))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'selector-receipt)
                          'selected-branch)
                'current-system-build-loop)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'selector-receipt)
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'resource-dispatch-receipt)
                          'contract)
                'agentic-ai-lab.loop-engine.resource-dispatch-receipt.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'resource-dispatch-receipt)
                          'tool-refs)
                '(run-shell-command write-workspace-file read-workspace-file))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'resource-dispatch-receipt)
                          'dispatch-groups)
                '(((run-shell-command) . serial)
                  ((write-workspace-file read-workspace-file) . serial)))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'resource-dispatch-receipt)
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'capability-receipt)
                          'unsupported-behavior)
                'handoff-diagnostic)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'capability-receipt)
                          'valid?)
                #t)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'commit)
                '(decision-summary evidence-index handoff-receipt))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'policy-count)
                2)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'available-use-cases)
                '(current-system-build-loop
                  current-system-recovery-loop))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'selected-policy-found?)
                #t)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'state-path)
                "loop-state/current-system-build.org")
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'memory-receipt)
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'contract)
                'agentic-ai-lab.loop-engine.compression-receipt.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'strategy)
                'handoff-summary)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'lineage-kind)
                'compressed-ci-session)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'source-session-ref)
                'loop-engine/current-system-build-loop/session)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'compressed-session-ref)
                'loop-engine/current-system-build-loop/compressed-session)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'compression-receipt)
                          'runtime-executed)
                #f)
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-human-audit-review-items)
                 'pattern)
                (list expected-loop-engine-spec-evolution-proposal-id))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'eligible-for-checked-mutation)
                '(#t))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'runtime-executed)
                '(#f))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'session-selector-receipts)
                 'selector-id)
                '(selector/current-system-loop-router))
  (check-equal? (test-ref (car (test-ref runtime-manifest-request
                                          'session-selector-receipts))
                          'candidate-ids)
                '(candidate/current-build candidate/current-recovery))
  (check-equal? (test-ref (car (test-ref runtime-manifest-request
                                          'session-selector-receipts))
                          'fallback-ref)
                'candidate/current-build)
  (check-equal? (test-ref (car (test-ref runtime-manifest-request
                                          'session-selector-receipts))
                          'selection-state)
                'pending)
  (check-equal? (test-ref (car (test-ref runtime-manifest-request
                                          'session-selector-receipts))
                          'selected-candidate-ref)
                #f)
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'session-materialization-receipts)
                 'session-ref)
                '(current-system-build-session
                  current-system-recovery-session))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'session-materialization-receipts)
                 'runtime-executed)
                '(#f #f))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-human-audit-review-items)
                 'decision)
                '(approved))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'schema)
                '(agentic-ai-lab.spec-evolution.runtime-manifest-row.v1))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'human-audit-decision)
                '(approved))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'eligible-for-checked-mutation)
                '(#t))
  (check-equal? (test-field-values
                 (test-ref runtime-manifest-request
                           'spec-evolution-runtime-manifest-rows)
                 'runtime-executed)
                '(#f)))
