;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-selector scenario.
;;; Invariant: selectors are pending routing receipts; Marlin owns scoring,
;;; dispatch, and selected result materialization.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/session-selector"
                 poo-flow-custom-my-module-session-selector-case))

(export user-interface-custom-session-selector-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Alist])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (poo-flow-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-selector-test
  (test-suite "poo-flow custom user-interface session-selector case"
    (poo-flow-test-case "projects custom selector receipt without dispatch"
      (let* ((selection
              (car poo-flow-custom-my-module-session-selector-case))
             (rows
              (module-config-rows
               poo-flow-custom-my-module-session-selector-case))
             (row (car rows))
             (candidates (test-ref row 'candidates))
             (build-candidate (car candidates))
             (governor-candidate (list-ref candidates 2)))
        (check-equal? (poo-flow-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (test-ref row 'kind)
                      'poo-flow.session.selector-receipt)
        (check-equal? (test-ref row 'selector-id)
                      'selector/custom-router)
        (check-equal? (test-ref row 'candidate-count) 3)
        (check-equal? (test-ref row 'candidate-ids)
                      '(candidate/build candidate/audit candidate/governor))
        (check-equal? (test-ref row 'workflow-candidate-ids)
                      '(candidate/audit))
        (check-equal? (test-ref row 'transform-candidate-ids)
                      '(candidate/build))
        (check-equal? (test-ref row 'agent-param-candidate-ids)
                      '(candidate/governor))
        (check-equal? (test-ref row 'resolved-candidate-ids)
                      '(candidate/build candidate/audit candidate/governor))
        (check-equal? (test-ref row 'unresolved-candidate-ids)
                      '())
        (check-equal? (length candidates) 3)
        (check-equal? (test-ref build-candidate 'description)
                      "Run the build sub-agent transform.")
        (check-equal? (test-ref governor-candidate 'target-ref)
                      'agent-param/custom-build)
        (check-equal? (test-ref row 'selection-state) 'pending)
        (check-equal? (test-ref row 'fallback-ref) 'empty-workflow)
        (check-equal? (test-ref row 'fallback-resolved?) #t)
        (check-equal? (test-ref row 'valid?) #t)
        (check-equal? (test-ref row 'diagnostic-count) 0)
        (check-equal? (test-ref row 'diagnostics) '())
        (check-equal? (test-ref row 'runtime-executed) #f)))))
