;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only selector receipts over workflow/transform candidates.
;;; Invariant: Scheme never scores candidates, calls a model, dispatches a
;;; workflow, or returns an EmptyWorkflow; it emits pending routing receipts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object object?)
        :agentic-ai-lab/modules/session/config)

(export session-selector-receipt-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def session-selector-receipt-test
  (test-suite "agentic-ai-lab session selector receipts"
    (yuanxu-test-case "declares pending selector routing without runtime dispatch"
      (let* ((build-candidate
              (agentic-ai-lab-session-selector-candidate
               'candidate/build
               'transform
               'transform/build
               "Run build verification."
               '(derived-session handoff-intent)))
             (audit-candidate
              (agentic-ai-lab-session-selector-candidate
               'candidate/audit
               'workflow
               'workflow/audit
               "Audit the build result."
               '(runtime-handoff diagnostics)))
             (governor-candidate
              (agentic-ai-lab-session-selector-candidate
               'candidate/governor
               'agent-param
               'agent-param/governor
               "Route to a policy governor agent."
               '(validation-valid? runtime-owner)))
             (receipt
              (agentic-ai-lab-session-selector-receipt
               'selector/build-router
               'project/selector
               'session/root
               'session/root
               (list build-candidate audit-candidate governor-candidate)
               '((strategy . llm-router)
                 (judge-inputs . (summary last-failure))
                 (result-contract . workflow-ref))
               'empty-workflow
               '((case . unit))))
             (row (agentic-ai-lab-session-selector-receipt->alist receipt)))
        (check-equal? (agentic-ai-lab-session-selector-candidate?
                       build-candidate)
                      #t)
        (check-equal? (object? build-candidate) #t)
        (check-equal? (agentic-ai-lab-session-selector-candidate-id
                       build-candidate)
                      'candidate/build)
        (check-equal? (agentic-ai-lab-session-selector-candidate-kind
                       audit-candidate)
                      'workflow)
        (check-equal? (agentic-ai-lab-session-selector-candidate-target-ref
                       governor-candidate)
                      'agent-param/governor)
        (check-equal? (agentic-ai-lab-session-selector-receipt? receipt) #t)
        (check-equal? (agentic-ai-lab-session-selector-receipt-selector-id
                       receipt)
                      'selector/build-router)
        (check-equal? (agentic-ai-lab-session-selector-receipt-candidate-ids
                       receipt)
                      '(candidate/build candidate/audit candidate/governor))
        (check-equal? (test-ref row 'transform-candidate-ids)
                      '(candidate/build))
        (check-equal? (test-ref row 'workflow-candidate-ids)
                      '(candidate/audit))
        (check-equal? (test-ref row 'agent-param-candidate-ids)
                      '(candidate/governor))
        (check-equal?
         (agentic-ai-lab-session-selector-receipt-selection-state receipt)
         'pending)
        (check-equal?
         (agentic-ai-lab-session-selector-receipt-selected-candidate-ref receipt)
         #f)
        (check-equal? (test-ref row 'fallback-ref) 'empty-workflow)
        (check-equal?
         (test-ref (car (test-ref row 'candidates)) 'description)
         "Run build verification.")
        (check-equal?
         (test-ref (car (test-ref row 'candidates))
                   'required-receipt-fields)
         '(derived-session handoff-intent))
        (check-equal? (test-ref (test-ref row 'pending-selected-result)
                                'state)
                      'pending)
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "allows no-candidate selectors only through explicit fallback"
      (let* ((receipt
              (agentic-ai-lab-session-selector-receipt
               'selector/no-candidate
               'project/selector
               'session/root
               'session/root
               '()
               '((strategy . no-candidate))
               'empty-workflow))
             (row (agentic-ai-lab-session-selector-receipt->alist receipt)))
        (check-equal? (test-ref row 'candidate-count) 0)
        (check-equal? (test-ref row 'candidate-ids) '())
        (check-equal? (test-ref row 'fallback-ref) 'empty-workflow)
        (check-equal? (test-ref row 'selected-candidate-ref) #f)))))
