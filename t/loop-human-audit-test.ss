;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: human audit loop tests cover review decisions over loop facts.
;;; Invariant: audit contracts never mutate config, state, or runtime handles.

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
        :poo-flow/modules/loop-engine/control/agent
        :poo-flow/modules/loop-engine/control/human-audit)

(export loop-human-audit-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; Field extraction uses map so assertions compare review projections by
;;; column while preserving the order emitted by the audit contract.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values alists key)
  (map (lambda (alist) (test-ref alist key))
       alists))

;;; Failure capture keeps negative cases expression-shaped; the protected
;;; control path returns the raised value for ordinary field assertions.
;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;; : (-> Symbol Symbol Integer ActionKey LoopPatternDescriptor)
(def (audit-test-pattern name level priority action-key)
  (make-loop-pattern-descriptor
   name
   "Exercise human audit loop review projection."
   (list (cons 'level level)
         (cons 'priority priority)
         (cons 'metadata
               (list (cons 'acting_on action-key))))))

;; : (-> Unit LoopGovernor)
(def (make-audit-governor-fixture)
  (let* ((repair-a (audit-test-pattern 'repair-a 'l2 10 "src/a"))
         (repair-b (audit-test-pattern 'repair-b 'l2 20 "src/b"))
         (repair-c (audit-test-pattern 'repair-c 'l2 30 "src/c"))
         (strategy
          (make-loop-strategy-plan
           'maintenance
           (list repair-c repair-b repair-a)
           (list (cons 'level-ceiling 'l2)))))
    (make-loop-governor
     'repo-governor
     strategy
     (list (cons 'shared-denylist '("src/b"))
           (cons 'aggregate-budget
                 '((max-actionable . 1)
                   (max-attempts . 2)))))))

;; : (-> Unit [Alist])
(def (audit-test-states)
  (list '((loop . other-loop)
          (acting_on . "src/a"))))

;;; The suite covers projection, defaulting, and rejection in one contract
;;; surface; inner lambdas are only failure thunks for the negative path.
;; : TestSuite
(def loop-human-audit-test
  (test-suite "loop human audit review contracts"
    (poo-flow-test-case "projects open and blocked loop facts into human review items"
      (let* ((audit
              (make-loop-human-audit
               'repo-review
               (make-audit-governor-fixture)
               (audit-test-states)
               '((repair-c . approved)
                 (repair-b . escalated)
                 (repair-a . changes-requested))))
             (contract (loop-human-audit->contract audit))
             (review-items (test-ref contract 'review-items))
             (agent-operation (test-ref contract 'agent-operation))
             (runtime-snapshot (test-ref contract 'runtime-snapshot)))
        (check-equal? (loop-human-audit? audit) #t)
        (check-equal? (test-ref contract 'schema)
                      +loop-human-audit-schema+)
        (check-equal? (test-ref contract 'kind) 'loop-human-audit)
        (check-equal? (test-ref contract 'review-count) 3)
        (check-equal? (test-ref agent-operation 'kind) 'agent-operation)
        (check-equal? (test-ref agent-operation 'operation-kind) 'human-audit)
        (check-equal? (test-ref agent-operation 'delegated-task?) #f)
        (check-equal? (test-ref agent-operation 'status) 'completed)
        (check-equal? (test-ref (test-ref agent-operation 'runtime-intent)
                                'executes-runtime)
                      #f)
        (check-equal? (test-ref runtime-snapshot 'kind) 'runtime-snapshot)
        (check-equal? (test-ref runtime-snapshot 'subject-kind) 'human-audit)
        (check-equal? (test-ref runtime-snapshot 'status) 'completed)
        (check-equal? (test-ref (test-ref runtime-snapshot
                                          'presentation-trace)
                                'runtime-executed)
                      #f)
        (check-equal? (test-ref (test-ref contract 'audit-boundary)
                                'governor-derived)
                      #t)
        (check-equal? (test-ref (test-ref contract 'audit-boundary)
                                'governance-node-kind)
                      'human)
        (check-equal? (test-ref (test-ref contract 'audit-boundary)
                                'human-intervention)
                      #t)
        (check-equal? (test-ref (test-ref contract 'audit-boundary)
                                'agent-judgement-source)
                      'consumed-governor-facts)
        (check-equal? (test-ref (test-ref contract 'audit-node)
                                'kind)
                      'loop-governance-node)
        (check-equal? (test-ref (test-ref contract 'audit-node)
                                'governance-node-kind)
                      'human)
        (check-equal? (test-ref (test-ref contract 'audit-node)
                                'governance-responsibility)
                      'human-audit)
        (check-equal? (test-ref (test-ref contract 'audit-node)
                                'human-intervention)
                      #t)
        (check-equal? (test-ref (test-ref (test-ref contract 'governor)
                                          'agent-judges)
                                'human-intervention)
                      #f)
        (check-equal? (test-field-values review-items 'pattern)
                      '(repair-c repair-b repair-a))
        (check-equal? (test-field-values review-items 'reason)
                      '(actionable-pattern shared-denylist
                        acting-on-conflict))
        (check-equal? (test-field-values review-items 'decision)
                      '(approved escalated changes-requested))
        (check-equal? (test-ref contract 'approved-patterns)
                      '(repair-c))
        (check-equal? (test-ref contract 'escalated-patterns)
                      '(repair-b))
        (check-equal? (test-ref contract 'changed-requested-patterns)
                      '(repair-a))
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'config-mutation)
                      'checked-interface-only)
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'governor-inheritance)
                      'poo-c4)
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'human-decision-state)
                      'review-loop)
        (check-equal? (test-ref contract 'decision-owner) 'human)
        (check-equal? (test-ref contract 'execution-owner)
                      'marlin-agent-core)))
    (poo-flow-test-case "defaults missing decisions to pending"
      (let* ((audit
              (make-loop-human-audit
               'repo-review
               (make-audit-governor-fixture)
               (audit-test-states)
               '()))
             (review-items
              (test-ref (loop-human-audit->contract audit)
                        'review-items))
             (runtime-snapshot
              (test-ref (loop-human-audit->contract audit)
                        'runtime-snapshot)))
        (check-equal? (test-field-values review-items 'decision)
                      '(pending pending pending))
        (check-equal? (test-ref runtime-snapshot 'status)
                      'waiting-human)))
    (poo-flow-test-case "rejects unsupported human decisions"
      (let* ((audit
              (make-loop-human-audit
               'bad-review
               (make-audit-governor-fixture)
               (audit-test-states)
               '((repair-c . auto-approved))))
             (failure
              (capture-control-plane-failure
               (lambda ()
                 (loop-human-audit->contract audit)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-human-audit)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-human-audit)))))
