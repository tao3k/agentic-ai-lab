;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify profile-style loop-engine user declarations.
;;; Invariant: profile projection is report-only and never executes loops.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        (only-in "../user-interface/custom/my-module/profiles/loops"
                 poo-flow-custom-my-module-loops-module))

(export user-interface-custom-loop-engine-profile-test)

;;; Intent rows are projected as alists for presentation only. The helper keeps
;;; this test at the public presentation boundary.
;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Field collection preserves projected row order so the test can catch
;;; accidental reordering in user-facing loop-engine policy rows.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;;; Semantic row lookup keeps memory-policy assertions tied to use-case names
;;; instead of brittle positional indexes.
;; : (-> [Alist] Symbol Value MaybeAlist)
(def (test-row-by-field rows key value)
  (cond
   ((null? rows) #f)
   ((equal? (test-ref (car rows) key) value) (car rows))
   (else (test-row-by-field (cdr rows) key value))))

;;; Expected result contract constants document the public profile projection
;;; shape that downstream agents see before runtime manifest expansion.
;; : Symbol
(def expected-loop-engine-profile-human-audit-result-contract
  'poo-flow.loop-governor.profile-human-audit-decision.v1)

;; : [Symbol]
(def expected-loop-engine-profile-required-result-fields
  '(decision summary evidence action-items))

;;; Presentation construction stays at the public facade so the case exercises
;;; the same module-selection path a downstream user configuration would use.
;; : (-> PooUserModuleSelection POOObject)
(def (custom-loop-presentation module-bundle)
  (pooFlowUserConfigPresentation
   (pooFlowUserConfig
    (poo-flow-user-module-bundles->modules (list module-bundle))
    (poo-flow-settings))))

;;; Profile modules should still read like user declarations: one loop-engine
;;; row, ordered use-cases, sandbox refs, and no runtime execution.
;; : TestCase
(def (user-interface-custom-loop-engine-profile-case)
  (poo-flow-test-case "projects custom loop-engine profile use cases"
    (let* ((presentation
            (custom-loop-presentation
             poo-flow-custom-my-module-loops-module))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (result-contract
            (test-ref intent 'result-contract)))
      (check-equal? (.ref presentation 'module-count) 1)
      (check-equal? (.ref presentation 'module-keys)
                    '((flow . loop-engine)))
      (check-equal? (.ref presentation 'loop-engine-intent-count) 1)
      (check-equal? (test-ref intent 'workflow-owned?) #t)
      (check-equal? (test-ref intent 'governor)
                    '(+strategy +policy +node-graph))
      (check-equal? (map car (test-ref intent 'use-cases))
                    '(daily-triage
                      ci-sweeper
                      issue-triage
                      dependency-sweeper
                      post-merge-cleanup))
      (check-equal? (test-ref intent 'sandbox)
                    '((daily-triage . agent/task)
                      (ci-sweeper . ci/build)
                      (issue-triage . agent/task)
                      (dependency-sweeper . agent/task-cache)
                      (post-merge-cleanup . agent/task)))
      (check-equal? (test-ref (test-ref intent 'lineage-policy)
                              'lineage-kind)
                    'profile-loop)
      (check-equal? (test-ref (test-ref intent 'selector-policy)
                              'selected-branch)
                    'daily-triage)
      (check-equal? (test-ref (test-ref intent 'resource-policy)
                              'dispatch-groups)
                    '(((inspect-policy write-report) . serial)
                      ((run-harness) . serial)))
      (check-equal? (test-ref (test-ref intent 'capability-policy)
                              'optional)
                    '(stream-events memory-recall compression-handoff))
      (let ((memory-policies (test-ref intent 'memory-policies)))
        (check-equal? (test-field-values memory-policies 'use-case)
                      '(daily-triage
                        ci-sweeper
                        issue-triage
                        dependency-sweeper
                        post-merge-cleanup))
        (check-equal? (test-ref (test-row-by-field memory-policies
                                                   'use-case
                                                   'daily-triage)
                                'state-path)
                      "STATE.md")
        (check-equal? (test-ref (test-row-by-field memory-policies
                                                   'use-case
                                                   'ci-sweeper)
                                'commit)
                      '(failure-classification attempt-count worktree-ref
                        verifier-result escalation-reason))
        (check-equal? (test-ref (test-row-by-field memory-policies
                                                   'use-case
                                                   'issue-triage)
                                'retention)
                      'rolling-backlog))
      (let ((memory-receipt (test-ref intent 'memory-receipt)))
        (check-equal? (test-ref memory-receipt 'selected-use-case)
                      'daily-triage)
        (check-equal? (test-ref memory-receipt 'policy-count) 5)
        (check-equal? (test-ref memory-receipt 'available-use-cases)
                      '(daily-triage
                        ci-sweeper
                        issue-triage
                        dependency-sweeper
                        post-merge-cleanup))
        (check-equal? (test-ref memory-receipt 'selected-policy-found?)
                      #t)
        (check-equal? (test-ref memory-receipt 'state-path) "STATE.md"))
      (check-equal? (test-ref (test-ref intent 'compression-policy)
                              'lineage-kind)
                    'compressed-profile-loop)
      (check-equal? (test-ref (test-ref intent 'compression-policy)
                              'trigger)
                    'before-release-approval)
      (check-equal? (test-ref intent 'result)
                    '((default
                       . poo-flow.loop-governor.profile-node-result.v1)
                      (auditor
                       . poo-flow.loop-governor.profile-audit-result.v1)
                      (verifier
                       . poo-flow.loop-governor.profile-review-result.v1)
                      (governor
                       . poo-flow.loop-governor.profile-governor-result.v1)
                      (human-audit
                       . poo-flow.loop-governor.profile-human-audit-decision.v1)
                      (format . structured-alist)
                      (required-fields
                       decision
                       summary
                       evidence
                       action-items)))
      (check-equal? (test-ref result-contract 'valid?) #t)
      (check-equal? (test-ref result-contract 'human-audit)
                    expected-loop-engine-profile-human-audit-result-contract)
      (check-equal? (test-ref result-contract 'required-fields)
                    expected-loop-engine-profile-required-result-fields)
      (check-equal? (car (.ref presentation 'loop-engine-result-contracts))
                    result-contract)
      (check-equal? (test-ref intent 'runtime-handoff)
                    'loop-governor-marlin-runtime-manifest)
      (check-equal? (test-ref intent 'runtime-handoff-contracts)
                    '(start-workflow-run
                      admit-dispatch
                      open-agent-session
                      execute-agent-operation
                      stream-events
                      read-runtime-snapshot))
      (check-equal? (test-ref intent 'runtime-executed) #f))))

;;; The suite is intentionally narrower than the runtime-manifest test: it
;;; proves the user-authored POO profile projects policy intent without crossing
;;; into ABI descriptor assembly.
;; : TestSuite
(def user-interface-custom-loop-engine-profile-test
  (test-suite "poo-flow custom loop-engine profile declarations"
    (user-interface-custom-loop-engine-profile-case)))
