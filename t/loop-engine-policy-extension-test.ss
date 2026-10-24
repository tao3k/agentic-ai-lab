;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused tests for loop-engine POO-native policy extensions.
;;; Invariant: extension receipts are report-only and runtime-owned by Marlin.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/loop-engine/policy-extension)

(export loop-engine-policy-extension-test)

;;; Test helpers intentionally operate on receipt alists, not internal POO
;;; objects, because the public contract here is the Marlin handoff surface.
;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Policy extensions share one generic receipt collection, so test lookup is
;;; keyed by receipt kind instead of by concrete Scheme prototype names.
;; : (-> [Alist] Symbol Value MaybeAlist)
(def (test-row-by-field rows key value)
  (cond
   ((null? rows) #f)
   ((equal? (test-ref (car rows) key) value) (car rows))
   (else (test-row-by-field (cdr rows) key value))))

;;; The receipt test owns the policy-extension lowering boundary directly. Full
;;; user-interface presentation propagation is covered by the runtime manifest
;;; and presentation tests.
;; : (-> [Alist])
(def (custom-loop-policy-extension-receipts)
  (agentic-ai-lab-user-loop-engine-poo-policy-extensions->receipts
   (list
    (.o (:: @ loop-engine-coordination-policy-extension)
        name: 'repo-loop-coordination
        scope: 'profile
        priority: '(ci-sweeper
                    dependency-sweeper
                    post-merge-cleanup
                    issue-triage
                    daily-triage)
        state-files: '((daily-triage . "STATE.md")
                       (ci-sweeper . "ci-sweeper-state.md")
                       (issue-triage . "issue-triage-state.md")
                       (dependency-sweeper
                        . "dependency-sweeper-state.md")
                       (post-merge-cleanup . "post-merge-state.md"))
        acting-on-key: 'acting_on
        conflict-action: 'skip-and-log
        branch-lock-scope: 'branch-or-pr
        human-inbox: "STATE.md#Human Inbox")
    (.o (:: @ loop-engine-observability-policy-extension)
        name: 'repo-loop-observability
        scope: 'profile
        run-log: "loop-run-log.md"
        run-log-schema: '((run_id . symbol)
                          (pattern . symbol)
                          (duration_s . integer)
                          (items_found . integer)
                          (actions_taken . integer)
                          (escalations . integer)
                          (tokens_estimate . integer)
                          (outcome . symbol))
        budget-path: "STATE.md#Loop Budget"
        metric-keys: '(duration_s items_found actions_taken escalations
                       tokens_estimate outcome)
        retention-window: 'rolling-fourteen-days
        slow-signals: '(budget-over-80 repeated-false-positive)
        pause-signals: '(main-red reviewer-absence repeated-escalation)
        kill-signals: '(incident cost-exceeds-value))
    (.o (:: @ loop-engine-safety-policy-extension)
        name: 'repo-loop-safety
        scope: 'profile
        denylist-paths: '(".env"
                          ".env.local"
                          "secrets/"
                          ".github/workflows/release.yml")
        allowlist-paths: '("src/"
                           "t/"
                           "docs/"
                           "user-interface/")
        human-gates: '(red-ci-handoff release-risk secrets-touch
                       protected-branch)
        connector-scopes: '(issues-read pull-requests-read actions-read)
        auto-merge: 'never
        max-attempts: 2))))

;;; Malformed extension slots fail before runtime manifests can carry ambiguous
;;; policy receipts.
;; : (-> AgenticAILabLoopEnginePolicyExtensionPrototype)
(def (custom-loop-invalid-policy-extension)
  (.o (:: @ loop-engine-policy-extension)
      name: 'invalid-policy-extension
      receipt-kind: 'coordination-receipt
      contract: 'agentic-ai-lab.loop-engine.coordination-receipt.v1
      priority: 'bad-priority))

;;; Coordination coverage proves cross-loop ownership and collision facts are
;;; carried as inert policy receipts rather than Scheme locks.
;; : TestCase
(def (loop-engine-policy-extension-coordination-case)
  (yuanxu-test-case "projects loop-engine coordination policy receipt"
    (let* ((receipts (custom-loop-policy-extension-receipts))
           (coordination-receipt
            (test-row-by-field receipts 'kind 'coordination-receipt))
           (observability-receipt
            (test-row-by-field receipts 'kind 'observability-receipt))
           (safety-receipt
            (test-row-by-field receipts 'kind 'safety-receipt)))
      (check-equal? (length receipts) 3)
      (check-equal? (test-ref coordination-receipt 'kind)
                    'coordination-receipt)
      (check-equal? (test-ref observability-receipt 'kind)
                    'observability-receipt)
      (check-equal? (test-ref safety-receipt 'kind)
                    'safety-receipt)
      (check-equal? (test-ref coordination-receipt 'contract)
                    'agentic-ai-lab.loop-engine.coordination-receipt.v1)
      (check-equal? (test-ref coordination-receipt 'priority)
                    '(ci-sweeper
                      dependency-sweeper
                      post-merge-cleanup
                      issue-triage
                      daily-triage))
      (check-equal? (test-ref coordination-receipt 'state-files)
                    '((daily-triage . "STATE.md")
                      (ci-sweeper . "ci-sweeper-state.md")
                      (issue-triage . "issue-triage-state.md")
                      (dependency-sweeper
                       . "dependency-sweeper-state.md")
                      (post-merge-cleanup . "post-merge-state.md")))
      (check-equal? (test-ref coordination-receipt 'acting-on-key)
                    'acting_on)
      (check-equal? (test-ref coordination-receipt 'conflict-action)
                    'skip-and-log)
      (check-equal? (test-ref coordination-receipt 'branch-lock-scope)
                    'branch-or-pr)
      (check-equal? (test-ref coordination-receipt 'human-inbox)
                    "STATE.md#Human Inbox")
      (check-equal? (test-ref coordination-receipt 'runtime-executed)
                    #f))))

;;; Observability coverage proves run-log, budget, and lifecycle signals are
;;; declared as receipt data while Marlin retains execution control.
;; : TestCase
(def (loop-engine-policy-extension-observability-case)
  (yuanxu-test-case "projects loop-engine observability policy receipt"
    (let* ((receipts (custom-loop-policy-extension-receipts))
           (observability-receipt
            (test-row-by-field receipts 'kind 'observability-receipt)))
      (check-equal? (test-ref observability-receipt 'contract)
                    'agentic-ai-lab.loop-engine.observability-receipt.v1)
      (check-equal? (test-ref observability-receipt 'run-log)
                    "loop-run-log.md")
      (check-equal? (test-ref observability-receipt 'metric-keys)
                    '(duration_s items_found actions_taken escalations
                      tokens_estimate outcome))
      (check-equal? (test-ref observability-receipt 'pause-signals)
                    '(main-red reviewer-absence repeated-escalation))
      (check-equal? (test-ref observability-receipt 'runtime-executed)
                    #f))))

;;; Safety coverage proves path, connector, and human-gate policy facts are
;;; visible without enabling Scheme-side mutations.
;; : TestCase
(def (loop-engine-policy-extension-safety-case)
  (yuanxu-test-case "projects loop-engine safety policy receipt"
    (let* ((receipts (custom-loop-policy-extension-receipts))
           (safety-receipt
            (test-row-by-field receipts 'kind 'safety-receipt)))
      (check-equal? (test-ref safety-receipt 'contract)
                    'agentic-ai-lab.loop-engine.safety-receipt.v1)
      (check-equal? (test-ref safety-receipt 'denylist-paths)
                    '(".env"
                      ".env.local"
                      "secrets/"
                      ".github/workflows/release.yml"))
      (check-equal? (test-ref safety-receipt 'human-gates)
                    '(red-ci-handoff release-risk secrets-touch
                      protected-branch))
      (check-equal? (test-ref safety-receipt 'auto-merge) 'never)
      (check-equal? (test-ref safety-receipt 'max-attempts) 2)
      (check-equal? (test-ref safety-receipt 'runtime-executed)
                    #f))))

;;; Collection coverage keeps the family tests separate from the invariant
;;; that every extension receipt is lowered through the generic receipt list.
;; : TestCase
(def (loop-engine-policy-extension-collection-case)
  (yuanxu-test-case "lowers policy-extension receipts through the generic collection"
    (let (receipts (custom-loop-policy-extension-receipts))
      (check-equal? (map (lambda (receipt) (test-ref receipt 'kind))
                         receipts)
                    '(coordination-receipt
                      observability-receipt
                      safety-receipt))
      (check-equal? (map (lambda (receipt)
                           (test-ref receipt 'runtime-owner))
                         receipts)
                    '("marlin-agent-core"
                      "marlin-agent-core"
                      "marlin-agent-core")))))

;;; Invalid-slot coverage keeps policy-extension mixins honest: malformed slot
;;; values must fail before any runtime handoff row can be assembled.
;; : TestCase
(def (loop-engine-policy-extension-invalid-slot-case)
  (yuanxu-test-case "rejects invalid loop-engine policy-extension slot types"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (agentic-ai-lab-user-loop-engine-poo-policy-extensions->receipts
         (list (custom-loop-invalid-policy-extension)))
        #f))
     #t)))

;;; The suite covers both the positive receipt propagation path and the contract
;;; rejection path for POO-native loop-engine policy extensions.
;; : TestSuite
(def loop-engine-policy-extension-test
  (test-suite "loop-engine POO-native policy extension"
    (loop-engine-policy-extension-coordination-case)
    (loop-engine-policy-extension-observability-case)
    (loop-engine-policy-extension-safety-case)
    (loop-engine-policy-extension-collection-case)
    (loop-engine-policy-extension-invalid-slot-case)))
