;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-agent tests cover POO/C4 policy descriptors only.
;;; Invariant: scheduling and execution stay out of this test surface.

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
        :agentic-ai-lab/modules/loop-engine/control/agent)

(export loop-agent-descriptor-test)

;;; Local lookup keeps descriptor assertions concise without depending on field
;;; order in contract alists.
;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; Failure capture keeps invalid descriptor checks on structured policy data.
;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; This suite keeps loop-agent descriptor policy executable without invoking
;;; the loop governor runtime.
;; : TestSuite
(def loop-agent-descriptor-test
  (test-suite "loop-agent POO policy descriptors"
    (yuanxu-test-case "declares L1 report-only descriptor defaults"
      (let* ((descriptor
              (make-loop-pattern-descriptor
               'daily-triage
               "Summarize repository state and escalate action items."))
             (contract (loop-pattern-descriptor->contract descriptor)))
        (check-equal? (loop-pattern-descriptor? descriptor) #t)
        (check-equal? (loop-pattern-name descriptor) 'daily-triage)
        (check-equal? (loop-pattern-level descriptor) 'l1)
        (check-equal? (loop-pattern-report-only? descriptor) #t)
        (check-equal? (loop-pattern-actionable? descriptor) #f)
        (check-equal? (loop-pattern-control-owner descriptor) 'gerbil)
        (check-equal? (loop-pattern-execution-owner descriptor)
                      'marlin-agent-core)
        (check-equal? (car (loop-pattern-policy-order descriptor)) 'safety)
        (check-equal? (test-ref contract 'schema) +loop-pattern-schema+)
        (check-equal? (test-ref contract 'execution-owner)
                      'marlin-agent-core)))
    (yuanxu-test-case "overrides autonomy, safety, budget, maker, and checker policy"
      (let* ((overrides
              (list (cons 'level 'l2)
                    (cons 'priority 20)
                    (cons 'watched-scope '(pull-requests ci))
                    (cons 'budget '((max-attempts . 2)
                                    (token-cap . 200000)))
                    (cons 'isolation '((mode . worktree)))
                    (cons 'maker '((agent . implementer)
                                   (can-write . #t)))
                    (cons 'checker '((agent . verifier)
                                     (required . #t)))
                    (cons 'safety
                          '((human-gates . (security dependency-upgrade repeated-failure))
                            (denylist . ("infra/**" "secrets/**"))
                            (auto-merge . #f)))
                    (cons 'metadata '((source . loop-engineering)))))
             (descriptor
              (make-loop-pattern-descriptor
               'pr-babysitter
               "Watch active PRs and prepare verified fixes."
               overrides))
             (contract (loop-pattern-descriptor->contract descriptor)))
        (check-equal? (loop-pattern-level descriptor) 'l2)
        (check-equal? (loop-pattern-report-only? descriptor) #f)
        (check-equal? (loop-pattern-actionable? descriptor) #t)
        (check-equal? (loop-pattern-human-gate-required?
                       descriptor
                       'dependency-upgrade)
                      #t)
        (check-equal? (test-ref contract 'priority) 20)
        (check-equal? (test-ref (test-ref contract 'maker) 'can-write) #t)
        (check-equal? (test-ref contract 'metadata)
                      '((source . loop-engineering)))))
    (yuanxu-test-case "compares autonomy levels"
      (check-equal? (loop-pattern-level-rank 'l1) 1)
      (check-equal? (loop-pattern-level-rank 'l3) 4)
      (check-equal? (loop-pattern-level<=? 'l2 'l3) #t)
      (check-equal? (loop-pattern-level<=? 'l3 'l2) #f))
    (yuanxu-test-case "rejects unsupported autonomy levels"
      (let* ((descriptor
              (make-loop-pattern-descriptor
               'bad-loop
               "This loop has an invalid level."
               (list (cons 'level 'l4))))
             (failure
              (capture-control-plane-failure
               (lambda ()
                 (loop-pattern-descriptor->contract descriptor)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-pattern)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-pattern-descriptor)))))
