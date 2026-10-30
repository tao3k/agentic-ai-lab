;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-strategy tests cover policy selection and handoff projection.
;;; Invariant: tests assert harness-only local validation, not runtime execution.

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

(export loop-strategy-test)

;;; Local lookup makes strategy contract assertions independent of alist order.
;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; Name projection keeps priority-order assertions focused on selected pattern
;;; identity rather than full descriptor payloads.
;; : (-> [Alist] [Symbol])
(def (contract-pattern-names contracts)
  (map (lambda (contract) (test-ref contract 'name))
       contracts))

;;; Failure capture keeps invalid strategy checks on structured policy errors.
;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; Pattern fixtures expose level and priority at construction sites so strategy
;;; selection rules remain easy to audit.
;; : (-> Symbol Symbol Integer LoopPatternDescriptor)
(def (test-pattern name level priority)
  (make-loop-pattern-descriptor
   name
   "Exercise loop strategy selection."
   (list (cons 'level level)
         (cons 'priority priority))))

;;; This suite keeps loop strategy semantics stable for both eager and deferred
;;; module execution paths.
;; : TestSuite
(def loop-strategy-test
  (test-suite "loop strategy policy selection"
    (yuanxu-test-case "selects priority-ordered patterns below autonomy ceiling"
      (let* ((triage (test-pattern 'daily-triage 'l1 5))
             (repair (test-pattern 'pr-repair 'l2 20))
             (migration (test-pattern 'dependency-migration 'l3 10))
             (plan
              (make-loop-strategy-plan
               'repo-maintenance
               (list repair migration triage)
               (list (cons 'level-ceiling 'l2)
                     (cons 'metadata '((source . loop-engineering))))))
             (contract (loop-strategy-plan->contract plan)))
        (check-equal? (loop-strategy-plan? plan) #t)
        (check-equal? (loop-strategy-control-owner plan) 'gerbil)
        (check-equal? (loop-strategy-execution-owner plan)
                      'marlin-agent-core)
        (check-equal? (loop-strategy-local-validation-harness-only? plan) #t)
        (check-equal? (map loop-pattern-name
                           (loop-strategy-selected-patterns plan))
                      '(daily-triage pr-repair))
        (check-equal? (map loop-pattern-name
                           (loop-strategy-actionable-patterns plan))
                      '(pr-repair))
        (check-equal? (loop-pattern-name (loop-strategy-next-pattern plan))
                      'pr-repair)
        (check-equal? (contract-pattern-names
                       (test-ref contract 'selected-patterns))
                      '(daily-triage pr-repair))
        (check-equal? (test-ref contract 'actionable-patterns)
                      '(pr-repair))
        (check-equal? (test-ref (test-ref contract 'handoff) 'target)
                      'marlin-agent-core)
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'local-execution)
                      'validation-only)))
    (yuanxu-test-case "uses autonomy rank as tie breaker after priority"
      (let* ((planner (test-pattern 'planner 'l2 10))
             (connector (test-pattern 'connector-writer 'l2+ 10))
             (plan
              (make-loop-strategy-plan
               'tie-break
               (list planner connector)
               (list (cons 'level-ceiling 'l3)))))
        (check-equal? (map loop-pattern-name
                           (loop-strategy-selected-patterns plan))
                      '(connector-writer planner))))
    (yuanxu-test-case "finds human-gated patterns as policy facts"
      (let* ((safe (test-pattern 'safe-triage 'l1 1))
             (upgrade
              (make-loop-pattern-descriptor
               'upgrade-watch
               "Watch dependency upgrade work."
               (list (cons 'level 'l2)
                     (cons 'priority 2)
                     (cons 'safety
                           '((human-gates . (governor-approval security))
                             (denylist . ())
                             (auto-merge . #f))))))
             (plan
              (make-loop-strategy-plan
               'gate-scan
               (list safe upgrade))))
        (check-equal? (map loop-pattern-name
                           (loop-strategy-human-gated-patterns
                            plan
                            'governor-approval))
                      '(upgrade-watch))))
    (yuanxu-test-case "rejects plans that imply local production execution"
      (let* ((plan
              (make-loop-strategy-plan
               'bad-local-runtime
               (list (test-pattern 'repair 'l2 1))
               (list (cons 'local-validation
                           '((mode . production)
                             (allow-effects . #t))))))
             (failure
              (capture-control-plane-failure
               (lambda ()
                 (loop-strategy-plan->contract plan)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-strategy)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-strategy-plan)))
    (yuanxu-test-case "rejects invalid loop pattern descriptors"
      (let* ((bad-pattern
              (make-loop-pattern-descriptor
               'bad-loop
               "Unsupported level must fail strategy validation."
               (list (cons 'level 'l4))))
             (plan
              (make-loop-strategy-plan
               'bad-pattern-plan
               (list bad-pattern)))
             (failure
              (capture-control-plane-failure
               (lambda ()
                 (loop-strategy-plan->contract plan)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-strategy)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-strategy-plan)))))
