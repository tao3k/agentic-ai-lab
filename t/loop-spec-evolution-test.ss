;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: spec evolution proposals are Human Audit review inputs.
;;; Invariant: proposals never mutate config or execute runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :yuanxu/modules/funflow/control-plane/failure
        :agentic-ai-lab/modules/loop-engine/control/spec-evolution)

(export loop-spec-evolution-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;; : ExternalFeedbackReceipt
(def feedback-receipt
  (make-external-feedback-receipt
   'alpha-feedback-001
   'external-feedback-loop
   '((source . alpha-user)
     (signal . navigation-confusion))
   "Alpha users cannot find the sandbox profile switch."))

;; : SpecChangeProposal
(def spec-proposal
  (make-spec-change-proposal
   'sandbox-profile-switch-copy
   'spec
   'sandbox-profile-selection
   'clarify-user-interface-copy
   "Clarify the sandbox profile selection flow before runtime handoff."
   (list feedback-receipt)))

;; : TestSuite
(def loop-spec-evolution-test
  (test-suite "loop spec evolution review boundary"
    (yuanxu-test-case "projects external feedback and proposal as report-only facts"
      (let ((feedback-row (external-feedback-receipt->alist feedback-receipt))
            (proposal-row (spec-change-proposal->alist spec-proposal))
            (review-row
             (spec-change-proposal->human-audit-review-item spec-proposal)))
        (check-equal? (external-feedback-receipt? feedback-receipt) #t)
        (check-equal? (test-ref feedback-row 'schema)
                      +spec-evolution-feedback-schema+)
        (check-equal? (test-ref feedback-row 'runtime-executed) #f)
        (check-equal? (spec-change-proposal? spec-proposal) #t)
        (check-equal? (test-ref proposal-row 'mutation-boundary)
                      'human-audit-required)
        (check-equal? (test-ref proposal-row 'direct-mutation) #f)
        (check-equal? (test-ref proposal-row 'runtime-executed) #f)
        (check-equal? (test-ref review-row 'reason)
                      'spec-evolution-proposal)
        (check-equal? (test-ref review-row 'pattern)
                      'sandbox-profile-switch-copy)
        (check-equal? (test-ref review-row 'decision) 'pending)
        (check-equal? (test-ref review-row 'direct-mutation) #f)))
    (yuanxu-test-case "approved Human Audit review enables checked mutation only"
      (let* ((review (make-spec-evolution-review-item spec-proposal 'approved))
             (review-row
              (spec-evolution-review-item->human-audit-review-item review))
             (manifest-row
              (spec-evolution-review-item->runtime-manifest-row review)))
        (check-equal? (spec-evolution-review-item? review) #t)
        (check-equal? (test-ref review-row 'decision) 'approved)
        (check-equal? (test-ref manifest-row 'schema)
                      +spec-evolution-manifest-row-schema+)
        (check-equal? (test-ref manifest-row 'human-audit-required) #t)
        (check-equal? (test-ref manifest-row 'human-audit-decision)
                      'approved)
        (check-equal? (test-ref manifest-row 'eligible-for-checked-mutation)
                      #t)
        (check-equal? (test-ref manifest-row 'direct-mutation) #f)
        (check-equal? (test-ref manifest-row 'runtime-executed) #f)))
    (yuanxu-test-case "unapproved reviews cannot reach checked mutation"
      (let* ((review (make-spec-evolution-review-item
                      spec-proposal
                      'changes-requested))
             (manifest-row
              (spec-evolution-review-item->runtime-manifest-row review)))
        (check-equal? (test-ref manifest-row 'human-audit-decision)
                      'changes-requested)
        (check-equal? (test-ref manifest-row 'eligible-for-checked-mutation)
                      #f)
        (check-equal? (test-ref manifest-row 'direct-mutation) #f)))
    (yuanxu-test-case "rejects unsupported target kinds and decisions"
      (let* ((bad-proposal
              (make-spec-change-proposal
               'bad-target
               'runtime
               'sandbox-profile-selection
               'unsafe-direct-runtime-change
               "Runtime is not a spec evolution target."
               (list feedback-receipt)))
             (bad-review
              (make-spec-evolution-review-item spec-proposal 'auto-approved))
             (proposal-failure
              (capture-control-plane-failure
               (lambda ()
                 (spec-change-proposal->alist bad-proposal))))
             (review-failure
              (capture-control-plane-failure
               (lambda ()
                 (spec-evolution-review-item->alist bad-review)))))
        (check-equal? (execution-failure? proposal-failure) #t)
        (check-equal? (execution-failure-code proposal-failure)
                      'invalid-spec-change-proposal)
        (check-equal? (execution-failure? review-failure) #t)
        (check-equal? (execution-failure-code review-failure)
                      'invalid-spec-evolution-review-item)))))
