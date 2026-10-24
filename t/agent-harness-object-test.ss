;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert agent harness/session/run object family tests.
;;; Invariant: projections distinguish workflow runs, sessions, and dispatches.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :yuanxu/modules/funflow/control-plane/api)

(export agent-harness-object-test)

;;; Test rows are total for the fields asserted below; missing keys should fail
;;; loudly through assoc rather than silently returning #f.
;; : (-> AgentHarnessTestRow Symbol AgentHarnessTestValue)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; The suite covers the user-visible alist projection for each inert object
;;; family, keeping runtime execution flags pinned to false.
;; : TestSuite
(def agent-harness-object-test
  (test-suite "agent harness object families"
    (yuanxu-test-case "projects inert profile harness session and operation facts"
      (let* ((profile
              (make-yuanxu-agent-profile
               'reviewer
               'anthropic/claude-sonnet-4-6
               "Review proposed changes and return structured findings."
               '(git diff)
               '(review)
               'agent/nono
               'loop/governor
               '((keep-recent-tokens . 8000))
               '((max-cost-usd . 3))
               '((sink . events))
               '((owner . user))))
             (harness
              (make-yuanxu-agent-harness
               'harness/reviewer
               'reviewer
               'agent/nono
               '((runtime . marlin-agent-core)
                 (mode . handoff))
               '(filesystem-read process-run)
               '(default review)
               'events
               #f
               '((case . cicd-review))))
             (session
              (make-yuanxu-agent-session
               'review-session
               'harness/reviewer
               'running
               'op/review
               'conversation/ref
               '((retention . parent-owned))
               '(op/setup op/review)
               '((workflow-run? . #f))))
             (operation
              (make-yuanxu-agent-operation
               'op/review
               'task
               'review-session
               #f
               '((prompt . "review"))
               'review-result
               '((runtime . marlin-agent-core))
               'running
               #f
               '((agent . reviewer))))
             (profile-row (yuanxu-agent-profile->alist profile))
             (harness-row (yuanxu-agent-harness->alist harness))
             (session-row (yuanxu-agent-session->alist session))
             (operation-row (yuanxu-agent-operation->alist operation))
             (session-snapshot
              (yuanxu-runtime-snapshot->alist
               (yuanxu-agent-session->snapshot session))))
        (check-equal? (yuanxu-agent-profile? profile) #t)
        (check-equal? (test-ref profile-row 'kind) 'agent-profile)
        (check-equal? (test-ref profile-row 'runtime-executed) #f)
        (check-equal? (test-ref harness-row 'kind) 'agent-harness)
        (check-equal? (test-ref harness-row 'runtime-executed) #f)
        (check-equal? (test-ref session-row 'kind) 'agent-session)
        (check-equal? (test-ref session-row 'workflow-run?) #f)
        (check-equal? (yuanxu-agent-operation-kind? 'task) #t)
        (check-equal? (yuanxu-agent-operation-kind? 'workflow-run) #f)
        (check-equal? (test-ref operation-row 'delegated-task?) #t)
        (check-equal? (test-ref session-snapshot 'subject-kind) 'agent-session)
        (check-equal? (test-ref session-snapshot 'subject-id) 'review-session)
        (check-equal? (test-ref session-snapshot 'last-event-index) 2)))
    (yuanxu-test-case "keeps workflow runs and dispatch receipts separate"
      (let* ((run
              (make-yuanxu-workflow-run
               'run_1
               'workflow/cicd
               'payload/ref
               'completed
               '(harness/reviewer)
               'events/run_1
               '((level . info))
               '((ok . #t))
               #f
               'receipt/ref
               '((last-event-index . 7))))
             (dispatch
              (make-yuanxu-dispatch-receipt
               'dispatch_1
               'reviewer
               'agent-instance-1
               'review-session
               'payload/ref
               "2026-06-20T00:00:00Z"
               'admitted
               '((queue . durable))
               '((source . test))))
             (run-row (yuanxu-workflow-run->alist run))
             (dispatch-row (yuanxu-dispatch-receipt->alist dispatch))
             (run-snapshot
              (yuanxu-runtime-snapshot->alist
               (yuanxu-workflow-run->snapshot run)))
             (dispatch-snapshot
              (yuanxu-runtime-snapshot->alist
               (yuanxu-dispatch-receipt->snapshot dispatch))))
        (check-equal? (test-ref run-row 'kind) 'workflow-run)
        (check-equal? (test-ref run-row 'run-id) 'run_1)
        (check-equal? (test-ref dispatch-row 'kind) 'dispatch-receipt)
        (check-equal? (test-ref dispatch-row 'workflow-run-id) #f)
        (check-equal? (test-ref dispatch-row 'dispatch-id) 'dispatch_1)
        (check-equal? (test-ref run-snapshot 'subject-kind) 'workflow-run)
        (check-equal? (test-ref run-snapshot 'subject-id) 'run_1)
        (check-equal? (test-ref run-snapshot 'last-event-index) 7)
        (check-equal? (test-ref dispatch-snapshot 'subject-kind)
                      'dispatch-receipt)
        (check-equal? (test-ref dispatch-snapshot 'status) 'admitted)
        (check-equal? (yuanxu-runtime-snapshot-status? 'admitted) #t)
        (check-equal? (yuanxu-runtime-snapshot-status? 'finished) #f)))
    (yuanxu-test-case "projects runner receipts into workflow run objects"
      (let* ((receipt
              (make-receipt
               'demo-flow
               #f
               'flow
               #f
               'local-eager
               '((strategy . local-eager)
                 (frontier . ()))
               'local
               #f
               'input-value
               'output-value
               'no-cache
               '()
               'ok
               #f
               '()))
             (run (yuanxu-receipt->workflow-run receipt 'run_from_receipt))
             (run-row (yuanxu-workflow-run->alist run))
             (snapshot
              (yuanxu-runtime-snapshot->alist
               (yuanxu-workflow-run->snapshot run)))
             (metadata (test-ref run-row 'metadata)))
        (check-equal? (test-ref run-row 'kind) 'workflow-run)
        (check-equal? (test-ref run-row 'run-id) 'run_from_receipt)
        (check-equal? (test-ref run-row 'workflow-ref) 'demo-flow)
        (check-equal? (test-ref run-row 'status) 'completed)
        (check-equal? (test-ref metadata 'source) 'receipt)
        (check-equal? (test-ref metadata 'event-count) 1)
        (check-equal? (test-ref snapshot 'subject-kind) 'workflow-run)
        (check-equal? (test-ref snapshot 'status) 'completed)))))
